#!/bin/bash
#
# Simple SSH-Based EC2 Deployment Script
#
# This script deploys the backend to EC2 using SSH (no SSM required)
# Much simpler and more reliable for small/beta applications
#
# Prerequisites:
# 1. SSH key configured in terraform (ssh_key_name variable)
# 2. Private key available locally (default: ~/.ssh/image-rec-key)
#
# Usage: ./deploy-ec2-simple.sh [path-to-private-key]
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

echo -e "${GREEN}=== Simple EC2 Deployment ===${NC}\n"

# Validate SSH key exists
if [ ! -f "$SSH_KEY" ]; then
  echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
  echo "Please provide the path to your private key:"
  echo "  ./deploy-ec2-simple.sh /path/to/your/key.pem"
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

# Step 2: Wait for instance to be running and accessible
echo -e "\n${YELLOW}Step 2: Waiting for EC2 instance to be ready...${NC}"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
echo "Instance is running"

# Wait for SSH to be available
echo "Waiting for SSH to be available..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${SSH_USER}@${EC2_IP} "echo 'SSH ready'" &>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for SSH..."
  sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo -e "${RED}Error: SSH connection timeout${NC}"
  echo "Please check:"
  echo "1. Security group allows SSH from your IP"
  echo "2. SSH key is correct"
  echo "3. Instance is fully booted"
  exit 1
fi

# Step 3: Build Docker image
echo -e "\n${YELLOW}Step 3: Building Docker image...${NC}"
cd ../backend
IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "local-$(date +%s)")
docker build -t image-rec-backend:$IMAGE_TAG .
docker tag image-rec-backend:$IMAGE_TAG image-rec-backend:latest

# Step 4: Save and compress Docker image
echo -e "\n${YELLOW}Step 4: Saving Docker image...${NC}"
docker save image-rec-backend:latest | gzip > /tmp/image-rec-backend.tar.gz
IMAGE_SIZE=$(du -h /tmp/image-rec-backend.tar.gz | cut -f1)
echo "Image size: $IMAGE_SIZE"

# Step 5: Copy image to EC2
echo -e "\n${YELLOW}Step 5: Copying image to EC2 (this may take a few minutes)...${NC}"
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no /tmp/image-rec-backend.tar.gz ${SSH_USER}@${EC2_IP}:/tmp/

# Step 6: Load and start container on EC2
echo -e "\n${YELLOW}Step 6: Deploying on EC2...${NC}"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ${SSH_USER}@${EC2_IP} << 'ENDSSH'
  set -e
  echo "Loading Docker image..."
  docker load < /tmp/image-rec-backend.tar.gz

  echo "Stopping existing container (if any)..."
  docker stop image-rec-backend 2>/dev/null || true
  docker rm image-rec-backend 2>/dev/null || true

  echo "Reloading systemd and restarting service..."
  sudo systemctl daemon-reload
  sudo systemctl enable image-rec-backend
  sudo systemctl restart image-rec-backend

  echo "Waiting for service to start..."
  sleep 5

  echo "Service status:"
  sudo systemctl status image-rec-backend --no-pager || true

  echo "Cleaning up temporary files..."
  rm /tmp/image-rec-backend.tar.gz
ENDSSH

# Clean up local tar file
rm /tmp/image-rec-backend.tar.gz

# Step 7: Health check
echo -e "\n${YELLOW}Step 7: Running health check...${NC}"
sleep 3

if curl -f -s http://$EC2_IP:8000/health > /dev/null; then
  echo -e "${GREEN}✓ Health check passed!${NC}"
else
  echo -e "${YELLOW}Warning: Health check failed. Service may still be starting...${NC}"
  echo "Check logs with: ssh -i $SSH_KEY ${SSH_USER}@${EC2_IP} 'sudo journalctl -u image-rec-backend -n 50'"
fi

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "Backend URL: http://$EC2_IP:8000"
echo -e "\nUseful commands:"
echo -e "  Test API:        curl http://$EC2_IP:8000/health"
echo -e "  SSH to server:   ssh -i $SSH_KEY ${SSH_USER}@${EC2_IP}"
echo -e "  View logs:       ssh -i $SSH_KEY ${SSH_USER}@${EC2_IP} 'sudo journalctl -u image-rec-backend -f'"
echo -e "  Check status:    ssh -i $SSH_KEY ${SSH_USER}@${EC2_IP} 'sudo systemctl status image-rec-backend'"
