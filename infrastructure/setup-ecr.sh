#!/bin/bash
#
# ECR Setup Script
#
# One-time setup to create ECR repository and configure permissions.
# Run this once before using deploy-ec2-ecr.sh
#
# Usage: ./setup-ecr.sh
#

set -e

# Configuration
AWS_REGION="us-east-1"
PROJECT_NAME="image-rec"
ECR_REPO_NAME="${PROJECT_NAME}-backend"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== ECR Setup ===${NC}\n"

# Check if repo already exists
EXISTING_REPO=$(aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION 2>/dev/null || echo "")

if [ ! -z "$EXISTING_REPO" ]; then
  echo -e "${YELLOW}ECR repository already exists!${NC}"
  ECR_URI=$(echo $EXISTING_REPO | jq -r '.repositories[0].repositoryUri')
  echo "Repository URI: $ECR_URI"
  exit 0
fi

# Create ECR repository
echo -e "${YELLOW}Creating ECR repository...${NC}"
aws ecr create-repository \
  --repository-name $ECR_REPO_NAME \
  --region $AWS_REGION \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

ECR_URI=$(aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text)

echo -e "${GREEN}✓ ECR repository created!${NC}"
echo "Repository URI: $ECR_URI"

# Set lifecycle policy to keep only last 5 images
echo -e "\n${YELLOW}Setting lifecycle policy (keep last 5 images)...${NC}"
cat > /tmp/ecr-lifecycle-policy.json << 'EOF'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep only last 5 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name $ECR_REPO_NAME \
  --region $AWS_REGION \
  --lifecycle-policy-text file:///tmp/ecr-lifecycle-policy.json

rm /tmp/ecr-lifecycle-policy.json

echo -e "${GREEN}✓ Lifecycle policy set${NC}"

echo -e "\n${GREEN}=== ECR Setup Complete ===${NC}"
echo -e "Repository: $ECR_URI"
echo -e "\nYou can now use ./deploy-ec2-ecr.sh for fast deployments!"
echo -e "\nEstimated deployment times:"
echo -e "  - First deploy: ~15 minutes (initial upload to ECR)"
echo -e "  - Subsequent: ~2-3 minutes (only changed layers + fast EC2 pull)"
