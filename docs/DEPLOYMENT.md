# Deployment Guide

This guide explains how to deploy the Image Recognition app using modern CI/CD practices with GitHub Actions and AWS ECS.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial AWS Infrastructure Setup](#initial-aws-infrastructure-setup)
4. [GitHub Secrets Configuration](#github-secrets-configuration)
5. [Deployment Workflow](#deployment-workflow)
6. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
7. [Rollback Procedures](#rollback-procedures)

---

## Overview

### Architecture

- **Backend**: FastAPI app running on AWS ECS Fargate
- **Frontend**: React app deployed to S3 + CloudFront (optional)
- **Database**: AWS RDS PostgreSQL
- **Container Registry**: AWS ECR
- **CI/CD**: GitHub Actions
- **Secrets Management**: AWS Secrets Manager + GitHub Secrets

### Deployment Flow

```
Push to main → GitHub Actions → Build Docker Image → Push to ECR → Update ECS Service
```

---

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured locally
3. **Terraform** installed (version >= 1.0)
4. **GitHub Repository** access
5. **Domain name** (optional, for custom domains)

---

## Initial AWS Infrastructure Setup

### Option 1: Using Terraform (Recommended)

1. **Navigate to Terraform directory:**
   ```bash
   cd infrastructure/terraform
   ```

2. **Create your variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars` with your values:**
   ```hcl
   aws_region     = "us-east-1"
   project_name   = "image-rec"
   environment    = "production"
   db_password    = "your-secure-password-here"  # Generate a strong password!
   s3_bucket_name = "image-rec-backend-unique-name"  # Must be globally unique
   ```

4. **Initialize Terraform:**
   ```bash
   terraform init
   ```

5. **Review the infrastructure plan:**
   ```bash
   terraform plan
   ```

6. **Apply the infrastructure:**
   ```bash
   terraform apply
   ```
   Type `yes` when prompted.

7. **Save the outputs:**
   ```bash
   terraform output > outputs.txt
   ```
   Keep these outputs secure - you'll need them for GitHub Secrets configuration.

### Option 2: Manual AWS Setup

If you prefer not to use Terraform, you can manually create:

1. **VPC** with public and private subnets
2. **ECR repositories** for backend and frontend images
3. **ECS cluster** with Fargate launch type
4. **Application Load Balancer** with target groups
5. **RDS PostgreSQL instance** in private subnet
6. **S3 bucket** for image storage
7. **IAM roles** for ECS task execution and task roles
8. **Secrets Manager secret** for database credentials and S3 bucket name

---

## GitHub Secrets Configuration

### Required Secrets

Navigate to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add the following secrets:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key with ECR, ECS, S3 permissions | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `REACT_APP_API_URL` | Backend API URL (ALB DNS or custom domain) | `http://image-rec-alb-123456.us-east-1.elb.amazonaws.com` |

### Creating AWS IAM User for GitHub Actions

1. **Create IAM user:**
   ```bash
   aws iam create-user --user-name github-actions-deploy
   ```

2. **Attach policies:**
   ```bash
   aws iam attach-user-policy --user-name github-actions-deploy \
     --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

   aws iam attach-user-policy --user-name github-actions-deploy \
     --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
   ```

3. **Create access key:**
   ```bash
   aws iam create-access-key --user-name github-actions-deploy
   ```
   Save the `AccessKeyId` and `SecretAccessKey` - add them to GitHub Secrets.

---

## Deployment Workflow

### Automatic Deployment

Once configured, deployments happen automatically:

1. **Push changes to `main` branch:**
   ```bash
   git add .
   git commit -m "Update backend API"
   git push origin main
   ```

2. **GitHub Actions will automatically:**
   - Detect changes in `backend/` or `frontend/` directories
   - Build Docker images
   - Push to AWS ECR
   - Update ECS task definition
   - Deploy new version to ECS
   - Wait for service stability

3. **Monitor deployment:**
   - Go to your GitHub repository → Actions tab
   - Click on the running workflow
   - View logs in real-time

### Manual Deployment

You can also trigger deployments manually:

1. Go to GitHub repository → Actions
2. Select the workflow (Deploy Backend or Deploy Frontend)
3. Click "Run workflow"
4. Select the branch and click "Run workflow"

---

## Monitoring and Troubleshooting

### View Application Logs

**AWS Console:**
1. Go to CloudWatch → Log groups
2. Select `/ecs/image-rec-backend`
3. View recent log streams

**AWS CLI:**
```bash
aws logs tail /ecs/image-rec-backend --follow
```

### Check ECS Service Status

```bash
aws ecs describe-services \
  --cluster image-rec-cluster \
  --services image-rec-backend-service
```

### Common Issues

**Issue: ECS tasks failing to start**
- Check CloudWatch logs for error messages
- Verify secrets are correctly configured in Secrets Manager
- Ensure security groups allow necessary traffic
- Verify IAM roles have correct permissions

**Issue: Health checks failing**
- Ensure your app has a `/health` endpoint
- Check security group rules allow ALB → ECS traffic
- Verify container is listening on correct port (8000)

**Issue: Cannot access application**
- Check ALB listener rules
- Verify target group health checks
- Ensure ALB security group allows inbound traffic on port 80/443

---

## Rollback Procedures

### Rollback to Previous Task Definition

1. **List task definitions:**
   ```bash
   aws ecs list-task-definitions \
     --family-prefix image-rec-backend \
     --sort DESC
   ```

2. **Update service to use previous version:**
   ```bash
   aws ecs update-service \
     --cluster image-rec-cluster \
     --service image-rec-backend-service \
     --task-definition image-rec-backend:PREVIOUS_REVISION
   ```

3. **Wait for deployment:**
   ```bash
   aws ecs wait services-stable \
     --cluster image-rec-cluster \
     --services image-rec-backend-service
   ```

---

## Security Best Practices

### Credentials Management

✅ **DO:**
- Store all secrets in AWS Secrets Manager or GitHub Secrets
- Rotate credentials regularly
- Use IAM roles with least privilege principle
- Enable MFA for AWS root account

❌ **DON'T:**
- Commit credentials to git
- Hardcode secrets in code or configs
- Use root AWS credentials for deployments
- Share credentials via email or chat

### Important Security Note

**URGENT**: The exposed credentials in `backend/README.md` (lines 75-78) must be:
1. Rotated immediately in AWS
2. Never committed to git again
3. Stored only in AWS Secrets Manager or GitHub Secrets

---

## Migrating from Old Manual Deployment

### Step-by-Step Migration

1. **Deploy new infrastructure** using Terraform
2. **Configure GitHub Secrets** with new credentials
3. **Push to trigger first automated deployment**
4. **Verify new deployment works correctly**
5. **Decommission old EC2 instances** after successful migration
6. **Rotate and delete old exposed credentials**

---

## Questions or Issues?

If you encounter any issues during deployment:
1. Check GitHub Actions logs for detailed error messages
2. Review CloudWatch logs for application errors
3. Verify all secrets are correctly configured
4. Ensure IAM permissions are properly set
