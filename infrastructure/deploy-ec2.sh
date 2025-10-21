#!/bin/bash
#
# EC2 Backend Deployment Script for Linux/Mac
#
# This script builds the backend Docker image and deploys it to EC2.
# It must be run ONCE after initial terraform apply.
# After that, this script or GitHub Actions can be used for deployments.
#
# Usage: ./deploy-ec2.sh
# Requirements: Docker, AWS CLI, Git, SSH access to EC2 (optional)

# Exit on any error
set -e

# Configuration
AWS_REGION="us-east-1"
PROJECT_NAME="image-rec"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting EC2 deployment process...${NC}"

# Step 1: Get EC2 instance ID and IP from Terraform
echo -e "\n${YELLOW}Step 1: Getting EC2 instance information...${NC}"
cd terraform
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null)
cd ..

if [ -z "$INSTANCE_ID" ] || [ -z "$EC2_IP" ]; then
  echo -e "${RED}Error: Could not get EC2 instance information from Terraform outputs${NC}"
  echo "Make sure you have run 'terraform apply' first"
  exit 1
fi

echo "Instance ID: $INSTANCE_ID"
echo "Instance IP: $EC2_IP"

# Step 2: Build the Docker image
echo -e "\n${YELLOW}Step 2: Building Docker image...${NC}"
cd ../backend
IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "local-$(date +%s)")
docker build -t image-rec-backend:$IMAGE_TAG .
docker tag image-rec-backend:$IMAGE_TAG image-rec-backend:latest

# Step 3: Save Docker image to tar file
echo -e "\n${YELLOW}Step 3: Saving Docker image...${NC}"
docker save image-rec-backend:latest | gzip > /tmp/image-rec-backend.tar.gz

# Step 4: Check if instance is ready
echo -e "\n${YELLOW}Step 4: Checking if EC2 instance is ready...${NC}"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
echo "Instance is running"

# Step 5: Wait for SSM agent to be ready
echo -e "\n${YELLOW}Step 5: Waiting for SSM agent to be ready...${NC}"
echo "This typically takes 5-10 minutes after instance creation."
echo "Checking SSM agent status every 30 seconds..."

MAX_ATTEMPTS=20  # 20 attempts * 30 seconds = 10 minutes
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  SSM_STATUS=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --region $AWS_REGION --query "InstanceInformationList[0].PingStatus" --output text 2>/dev/null || echo "NotAvailable")

  if [ "$SSM_STATUS" = "Online" ]; then
    echo -e "${GREEN}✓ SSM agent is online!${NC}"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: SSM status is '$SSM_STATUS', waiting..."
  sleep 30
done

# Step 6: Copy image to EC2 using AWS Systems Manager (no SSH key needed)
echo -e "\n${YELLOW}Step 6: Copying Docker image to EC2...${NC}"

if [ "$SSM_STATUS" = "Online" ]; then
  echo "Using AWS Systems Manager to deploy..."

  # Upload to S3 temporarily
  TEMP_BUCKET="${PROJECT_NAME}-deploy-temp-$RANDOM"
  aws s3 mb s3://$TEMP_BUCKET --region $AWS_REGION
  aws s3 cp /tmp/image-rec-backend.tar.gz s3://$TEMP_BUCKET/image-rec-backend.tar.gz

  # Download and load on EC2 via SSM
  COMMAND_ID=$(aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
      "aws s3 cp s3://'"$TEMP_BUCKET"'/image-rec-backend.tar.gz /tmp/image-rec-backend.tar.gz",
      "docker load < /tmp/image-rec-backend.tar.gz",
      "rm /tmp/image-rec-backend.tar.gz",
      "docker stop image-rec-backend 2>/dev/null || true",
      "docker rm image-rec-backend 2>/dev/null || true",
      "systemctl daemon-reload",
      "systemctl enable image-rec-backend",
      "systemctl restart image-rec-backend",
      "sleep 5",
      "systemctl status image-rec-backend"
    ]' \
    --region $AWS_REGION \
    --query "Command.CommandId" \
    --output text)

  echo "Waiting for deployment to complete..."
  aws ssm wait command-executed --command-id $COMMAND_ID --instance-id $INSTANCE_ID --region $AWS_REGION

  # Clean up S3 bucket
  aws s3 rb s3://$TEMP_BUCKET --force

else
  echo -e "${YELLOW}SSM not available. Please ensure:${NC}"
  echo "1. EC2 instance has SSM agent installed (should be automatic on Amazon Linux 2023)"
  echo "2. Instance has IAM role with SSM permissions"
  echo "3. Instance has been running for at least 5 minutes"
  echo ""
  echo -e "${YELLOW}Alternative: Deploy via SSH${NC}"
  echo "If you have SSH access configured, run:"
  echo "  scp /tmp/image-rec-backend.tar.gz ec2-user@$EC2_IP:/tmp/"
  echo "  ssh ec2-user@$EC2_IP 'docker load < /tmp/image-rec-backend.tar.gz && systemctl restart image-rec-backend'"
  exit 1
fi

# Clean up local tar file
rm /tmp/image-rec-backend.tar.gz

echo -e "\n${GREEN}✓ Deployment successful!${NC}"
echo -e "Backend URL: http://$EC2_IP:8000"
echo -e "\nTest the deployment:"
echo -e "  curl http://$EC2_IP:8000/health"
