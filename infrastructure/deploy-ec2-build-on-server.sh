#!/bin/bash
#
# Build-on-Server Deployment Script
#
# This script transfers only the source code to EC2 and builds the Docker image there.
# Perfect for large images (ML/AI apps) where uploading the built image takes too long.
#
# First deployment: ~10-15 minutes (building on server)
# Subsequent deploys: ~5-8 minutes (Docker layer caching)
#
# Usage: ./deploy-ec2-build-on-server.sh [path-to-private-key]
#

set -e

# Configuration
AWS_REGION="us-east-1"
PROJECT_NAME="image-rec"
SSH_KEY="${1:-$HOME/.ssh/image-rec-key}"
SSH_USER="ec2-user"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Build-on-Server EC2 Deployment ===${NC}\n"

# Validate SSH key exists
if [ ! -f "$SSH_KEY" ]; then
  echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
  echo "Please provide the path to your private key:"
  echo "  ./deploy-ec2-build-on-server.sh /path/to/your/key.pem"
  exit 1
fi

# Step 1: Get EC2 IP from Terraform
echo -e "${YELLOW}Step 1: Getting EC2 instance IP...${NC}"
cd terraform
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null)
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
cd ..

if [ -z "$EC2_IP" ]; then
  echo -e "${RED}Error: Could not get EC2 IP from Terraform${NC}"
  echo "Make sure you have run 'terraform apply' first"
  exit 1
fi

echo "Instance ID: $INSTANCE_ID"
echo "Instance IP: $EC2_IP"

# Step 2: Wait for instance to be ready
echo -e "\n${YELLOW}Step 2: Waiting for EC2 instance to be ready...${NC}"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
echo "Instance is running"

# Remove old SSH host key if it exists (happens when instance is recreated)
echo "Removing old SSH host key (if any)..."
ssh-keygen -R $EC2_IP 2>/dev/null || true

# Wait for SSH
echo "Waiting for SSH to be available..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 ${SSH_USER}@${EC2_IP} "echo 'SSH ready'" &>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for SSH..."
  sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo -e "${RED}Error: SSH connection timeout${NC}"
  exit 1
fi

# Step 3: Create tarball of backend source (much smaller than Docker image!)
echo -e "\n${YELLOW}Step 3: Packaging backend source code...${NC}"
cd ../backend
tar -czf /tmp/backend-source.tar.gz \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='.pytest_cache' \
  --exclude='venv' \
  --exclude='.env' \
  Dockerfile requirements.txt src/

SOURCE_SIZE=$(du -h /tmp/backend-source.tar.gz | cut -f1)
echo "Source package size: $SOURCE_SIZE (vs ~6GB for full Docker image!)"

# Step 4: Copy source to EC2
echo -e "\n${YELLOW}Step 4: Copying source to EC2 (~10 seconds)...${NC}"
scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new /tmp/backend-source.tar.gz ${SSH_USER}@${EC2_IP}:/tmp/

# Clean up local tarball
rm /tmp/backend-source.tar.gz

# Step 5: Build and deploy on EC2
echo -e "\n${YELLOW}Step 5: Building Docker image on EC2...${NC}"
echo "This will take ~10-15 minutes on first deploy (downloading PyTorch, etc.)"
echo "Subsequent deploys will be faster due to Docker layer caching."
echo ""

IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "local-$(date +%s)")

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new ${SSH_USER}@${EC2_IP} << ENDSSH
  set -e

  # Check disk space and cleanup if needed
  echo "Checking disk space..."
  AVAILABLE_GB=\$(df / --output=avail | tail -1 | awk '{print int(\$1/1024/1024)}')
  echo "Available space: \${AVAILABLE_GB}GB"

  if [ \$AVAILABLE_GB -lt 15 ]; then
    echo "Warning: Low disk space. Cleaning up old Docker images..."
    docker image prune -a -f || true
    docker system prune -f || true
    echo "Space after cleanup: \$(df -h / | grep '/$' | awk '{print \$4}')"
  fi

  # Extract source
  echo "Extracting source code..."
  mkdir -p /tmp/backend-build
  cd /tmp/backend-build
  tar -xzf /tmp/backend-source.tar.gz
  rm /tmp/backend-source.tar.gz

  # Build Docker image (this is the slow part, but only first time!)
  echo "Building Docker image (please wait, this takes time on first build)..."
  docker build -t image-rec-backend:${IMAGE_TAG} .
  docker tag image-rec-backend:${IMAGE_TAG} image-rec-backend:latest

  # Clean up source
  cd /
  rm -rf /tmp/backend-build

  # Deploy
  echo "Stopping existing container..."
  docker stop image-rec-backend 2>/dev/null || true
  docker rm image-rec-backend 2>/dev/null || true

  echo "Starting new container..."
  sudo systemctl daemon-reload
  sudo systemctl enable image-rec-backend
  sudo systemctl restart image-rec-backend

  echo "Waiting for service to start..."
  sleep 5

  sudo systemctl status image-rec-backend --no-pager || true

  # Clean up old Docker images (keep only latest)
  echo "Cleaning up old Docker images..."
  docker image prune -f || true
  echo "Final disk space: \$(df -h / | grep '/$' | awk '{print \$4}')"
ENDSSH

# Step 6: Health check
echo -e "\n${YELLOW}Step 6: Running health check...${NC}"
sleep 3

if curl -f -s http://$EC2_IP:8000/health > /dev/null; then
  echo -e "${GREEN}✓ Health check passed!${NC}"
else
  echo -e "${YELLOW}Warning: Health check failed. Service may still be starting...${NC}"
  echo "Check logs with: ssh -i $SSH_KEY ${SSH_USER}@${EC2_IP} 'sudo journalctl -u image-rec-backend -n 50'"
fi

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "Backend URL: http://$EC2_IP:8000"
echo -e "\nDeployment stats:"
echo -e "  - First deploy: ~10-15 minutes (building ML dependencies)"
echo -e "  - Next deploys: ~5-8 minutes (Docker cache)"
echo -e "  - vs SCP method: 45+ minutes every time!"
echo -e "\nUseful commands:"
echo -e "  SSH to server:   ssh -i $SSH_KEY ${SSH_USER}@${EC2_IP}"
echo -e "  View logs:       ssh -i $SSH_KEY ${SSH_USER}@${EC2_IP} 'sudo journalctl -u image-rec-backend -f'"
