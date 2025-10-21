#!/bin/bash
#
# Docker Cleanup Script for EC2
#
# Cleans up old Docker images and containers to free up disk space.
# Safe to run anytime - only removes unused images.
#
# Usage: ./cleanup-docker.sh [path-to-private-key]
#

set -e

# Configuration
AWS_REGION="us-east-1"
SSH_KEY="${1:-$HOME/.ssh/image-rec-key}"
SSH_USER="ec2-user"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Docker Cleanup on EC2 ===${NC}\n"

# Validate SSH key
if [ ! -f "$SSH_KEY" ]; then
  echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
  exit 1
fi

# Get EC2 IP
echo -e "${YELLOW}Getting EC2 IP...${NC}"
cd terraform
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null)
cd ..

if [ -z "$EC2_IP" ]; then
  echo -e "${RED}Error: Could not get EC2 IP${NC}"
  exit 1
fi

echo "Connecting to: $EC2_IP"

# Run cleanup
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ${SSH_USER}@${EC2_IP} << 'EOF'
  set -e

  echo "===== BEFORE CLEANUP ====="
  echo "Disk usage:"
  df -h / | grep -E '(Filesystem|/$)'

  echo -e "\nDocker disk usage:"
  sudo docker system df

  echo -e "\nDocker images:"
  sudo docker images

  echo -e "\n===== CLEANING UP ====="

  echo "Removing stopped containers..."
  sudo docker container prune -f

  echo "Removing old/unused images (keeping image-rec-backend:latest)..."
  sudo docker image prune -a -f

  echo "Removing unused volumes..."
  sudo docker volume prune -f

  echo "Removing build cache..."
  sudo docker builder prune -a -f

  echo -e "\n===== AFTER CLEANUP ====="
  echo "Disk usage:"
  df -h / | grep -E '(Filesystem|/$)'

  echo -e "\nDocker disk usage:"
  sudo docker system df

  echo -e "\nRemaining images:"
  sudo docker images
EOF

echo -e "\n${GREEN}✓ Cleanup complete!${NC}"
echo "You should now have only the current image-rec-backend:latest image."
