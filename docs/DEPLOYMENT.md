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

- **Backend**: FastAPI app running on single AWS EC2 instance (Docker)
- **Frontend**: React app deployed to S3 + CloudFront (optional)
- **Database**: AWS RDS PostgreSQL
- **CI/CD**: GitHub Actions with AWS Systems Manager
- **Secrets Management**: AWS Secrets Manager + GitHub Secrets

### Deployment Flow

```
Push to main → GitHub Actions → Build Docker Image → Transfer to EC2 via SSM → Restart Service
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

8. **Deploy initial Docker image to EC2:**

   After Terraform creates the EC2 instance, you must deploy the initial Docker image to it.

   **On Windows:**
   ```powershell
   cd ../../infrastructure  # From terraform directory
   .\deploy-ec2.ps1
   ```

   **On Linux/Mac:**
   ```bash
   cd ../../infrastructure  # From terraform directory
   chmod +x deploy-ec2.sh
   ./deploy-ec2.sh
   ```

   This script will:
   - Build your backend Docker image
   - Save the image as a tar file
   - Transfer it to EC2 via AWS Systems Manager
   - Load and run the image on EC2
   - Start the backend service

   **Note:** This step is only required for initial setup. Future deployments will be automated via GitHub Actions.

### Option 2: Manual AWS Setup

If you prefer not to use Terraform, you can manually create:

1. **VPC** with public and private subnets
2. **EC2 instance** (t3.small or larger) with Amazon Linux 2023
3. **Elastic IP** for static IP address
4. **RDS PostgreSQL instance** in private subnet
5. **S3 bucket** for image storage
6. **IAM role** for EC2 with S3 and Secrets Manager permissions
7. **Security groups** for EC2 (ports 22, 80, 8000) and RDS (port 5432)
8. **Secrets Manager secret** for database credentials and S3 bucket name

---

## GitHub Secrets Configuration

### Required Secrets

Navigate to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add the following secrets:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key with EC2, SSM, S3 permissions | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `REACT_APP_API_URL` | Backend API URL (EC2 Elastic IP) | `http://44.200.123.45:8000` |

### Creating AWS IAM User for GitHub Actions

1. **Create IAM user:**
   ```bash
   aws iam create-user --user-name github-actions-deploy
   ```

2. **Attach policies:**
   ```bash
   aws iam attach-user-policy --user-name github-actions-deploy \
     --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess

   aws iam attach-user-policy --user-name github-actions-deploy \
     --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess

   aws iam attach-user-policy --user-name github-actions-deploy \
     --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
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
   - Build Docker image
   - Transfer image to EC2 via AWS Systems Manager
   - Stop old container and start new one
   - Restart the backend service

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

**SSH to EC2:**
```bash
ssh ec2-user@<EC2_IP>
sudo journalctl -u image-rec-backend -f
```

**Or via Systems Manager:**
```bash
aws ssm start-session --target <INSTANCE_ID>
sudo journalctl -u image-rec-backend -f
```

**Docker logs:**
```bash
ssh ec2-user@<EC2_IP>
docker logs -f image-rec-backend
```

### Check Service Status

**Via SSH:**
```bash
ssh ec2-user@<EC2_IP>
sudo systemctl status image-rec-backend
```

**Via Systems Manager:**
```bash
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl status image-rec-backend"]'
```

### Common Issues

**Issue: Service not starting**
- SSH to EC2 and check logs: `sudo journalctl -u image-rec-backend -f`
- Verify secrets are correctly configured in Secrets Manager
- Ensure security groups allow traffic on port 8000
- Check Docker status: `docker ps -a`

**Issue: Cannot access application**
- Verify security group allows inbound on port 8000
- Check if service is running: `sudo systemctl status image-rec-backend`
- Test locally on EC2: `curl localhost:8000/health`
- Verify Elastic IP is attached to the instance

**Issue: Deployment via SSM fails**
- Ensure EC2 instance has IAM role with SSM permissions
- Check SSM agent status on EC2: `sudo systemctl status amazon-ssm-agent`
- Wait 5-10 minutes after instance launch for SSM to be ready

---

## Rollback Procedures

### Rollback to Previous Docker Image

1. **SSH to EC2:**
   ```bash
   ssh ec2-user@<EC2_IP>
   ```

2. **List available Docker images:**
   ```bash
   docker images image-rec-backend
   ```

3. **Update systemd service to use specific image tag:**
   ```bash
   sudo sed -i 's/image-rec-backend:latest/image-rec-backend:<OLD_TAG>/' /etc/systemd/system/image-rec-backend.service
   sudo systemctl daemon-reload
   sudo systemctl restart image-rec-backend
   ```

4. **Or deploy from backup:**
   - Re-run the deployment script with an older git commit checked out
   - Or manually load a saved Docker image: `docker load < backup.tar.gz`

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
