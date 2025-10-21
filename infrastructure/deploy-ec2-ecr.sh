#!/bin/bash
#
# ECR-Based Deployment Script
#
# This script uses AWS Elastic Container Registry (ECR) for fast, efficient deployments.
# Build locally once, push to ECR, then EC2 pulls from ECR (very fast).
#
# Setup time: 5 minutes (one-time ECR creation)
# First deployment: ~15 minutes (uploading to ECR)
# Subsequent deploys: ~2-3 minutes (only changed layers uploaded, fast EC2 pull)
#
# Prerequisites:
# 1. Run ./setup-ecr.sh first (one-time setup)
# 2. SSH key configured
#
# Usage: ./deploy-ec2-ecr.sh [path-to-private-key]
#

set -e

# Configuration
AWS_REGION="us-east-1"
PROJECT_NAME="image-rec"
SSH_KEY="${1:-$HOME/.ssh/image-rec-key}"
SSH_USER="ec2-user"
ECR_REPO_NAME="${PROJECT_NAME}-backend"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== ECR-Based EC2 Deployment ===${NC}\n"

# Validate SSH key exists
if [ ! -f "$SSH_KEY" ]; then
  echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
  exit 1
fi

# Step 1: Get infrastructure details
echo -e "${YELLOW}Step 1: Getting infrastructure details...${NC}"
cd terraform
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null)
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
cd ..

if [ -z "$EC2_IP" ]; then
  echo -e "${RED}Error: Could not get EC2 IP from Terraform${NC}"
  exit 1
fi

# Check if ECR repo exists
ECR_URI=$(aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text 2>/dev/null || echo "")

if [ -z "$ECR_URI" ]; then
  echo -e "${RED}Error: ECR repository not found${NC}"
  echo "Please run ./setup-ecr.sh first to create the ECR repository"
  exit 1
fi

echo "Instance ID: $INSTANCE_ID"
echo "Instance IP: $EC2_IP"
echo "ECR Repository: $ECR_URI"

# Step 2: Build Docker image locally
echo -e "\n${YELLOW}Step 2: Building Docker image locally...${NC}"
cd ../backend
IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "local-$(date +%s)")
docker build -t $ECR_REPO_NAME:$IMAGE_TAG .
docker tag $ECR_REPO_NAME:$IMAGE_TAG $ECR_REPO_NAME:latest

# Step 3: Push to ECR
echo -e "\n${YELLOW}Step 3: Pushing to ECR...${NC}"
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI

echo "Tagging for ECR..."
docker tag $ECR_REPO_NAME:$IMAGE_TAG $ECR_URI:$IMAGE_TAG
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest

echo "Pushing to ECR (first push is slow, subsequent pushes only upload changed layers)..."
docker push $ECR_URI:$IMAGE_TAG
docker push $ECR_URI:latest

# Step 4: Wait for SSH
echo -e "\n${YELLOW}Step 4: Connecting to EC2...${NC}"
MAX_ATTEMPTS=10
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

# Step 5: Pull and deploy on EC2
echo -e "\n${YELLOW}Step 5: Deploying on EC2 (pulling from ECR)...${NC}"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ${SSH_USER}@${EC2_IP} << ENDSSH
  set -e

  echo "Logging into ECR..."
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI

  echo "Pulling latest image from ECR (fast, within AWS network!)..."
  docker pull $ECR_URI:latest
  docker tag $ECR_URI:latest image-rec-backend:latest

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

  # Clean up old images to save disk space
  echo "Cleaning up old Docker images..."
  docker image prune -f
ENDSSH

# Step 6: Health check
echo -e "\n${YELLOW}Step 6: Running health check...${NC}"
sleep 3

if curl -f -s http://$EC2_IP:8000/health > /dev/null; then
  echo -e "${GREEN}✓ Health check passed!${NC}"
else
  echo -e "${YELLOW}Warning: Health check failed. Service may still be starting...${NC}"
fi

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "Backend URL: http://$EC2_IP:8000"
echo -e "Image: $ECR_URI:$IMAGE_TAG"
echo -e "\nDeployment stats:"
echo -e "  - First ECR push: ~15 minutes (uploading full image)"
echo -e "  - Subsequent pushes: ~3-5 minutes (only changed layers)"
echo -e "  - EC2 pull from ECR: ~1-2 minutes (fast AWS network)"
echo -e "  - Total subsequent deploys: ~2-3 minutes!"
