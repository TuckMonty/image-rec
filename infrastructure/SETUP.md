# EC2 Deployment Guide

This guide explains the different deployment options for your EC2 backend and when to use each.

## The Problem: 11.9GB Docker Image

Your app uses PyTorch + torchvision + faiss-cpu for image recognition, making the Docker image 11.9GB. Uploading this takes 45+ minutes on typical internet connections.

## Three Deployment Solutions

### 1. Build on Server (Recommended for Beta)
**Best for**: Infrequent deploys (1-2x per day)
- Transfers only source code (~100KB)
- Builds Docker image on EC2
- First deploy: 10-15 minutes
- Subsequent: 5-8 minutes (Docker cache)
- **Scripts**: `deploy-ec2-build-on-server.sh` / `.ps1`

### 2. AWS ECR (Recommended for Production)
**Best for**: Frequent deploys (3+ per day)
- Uses AWS container registry
- First deploy: 15 minutes (upload to ECR)
- Subsequent: 2-3 minutes (only changed layers)
- Requires one-time ECR setup
- **Scripts**: `setup-ecr.sh`, `deploy-ec2-ecr.sh`

### 3. Direct SCP (Not Recommended)
**Best for**: Never, unless you have no alternatives
- Transfers full 11.9GB image
- Every deploy: 45+ minutes
- No benefits
- **Scripts**: `deploy-ec2-simple.sh` (original)

## Prerequisites

1. **AWS CLI configured** with credentials that have EC2 permissions
2. **Docker** installed and running
3. **SSH client** (built into Linux/Mac/Windows 10+)
4. **SSH key pair** for EC2 access

## Step 1: Generate SSH Key Pair (if needed)

If you don't already have an SSH key for AWS:

### On Linux/Mac:
```bash
# Generate key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/image-rec-key -C "image-rec-deployment"

# Import to AWS
aws ec2 import-key-pair \
  --key-name "image-rec-key" \
  --public-key-material fileb://~/.ssh/image-rec-key.pub \
  --region us-east-1
```

### On Windows (PowerShell):
```powershell
# Generate key pair
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\image-rec-key" -C "image-rec-deployment"

# Import to AWS
aws ec2 import-key-pair `
  --key-name "image-rec-key" `
  --public-key-material "fileb://$env:USERPROFILE\.ssh\image-rec-key.pub" `
  --region us-east-1
```

## Step 2: Update Terraform Configuration

Edit `terraform/terraform.tfvars` and set your SSH key name:

```hcl
ssh_key_name = "image-rec-key"  # Use the key name you created above
```

## Step 3: Apply Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

The instance will be ready in 2-3 minutes (much faster than waiting for SSM!).

## Step 4: Deploy Your Application

### Option A: Build on Server (Recommended)

**Linux/Mac:**
```bash
cd infrastructure
chmod +x deploy-ec2-build-on-server.sh
./deploy-ec2-build-on-server.sh ~/.ssh/image-rec-key
```

**Windows:**
```powershell
cd infrastructure
.\deploy-ec2-build-on-server.ps1 -SshKeyPath "$env:USERPROFILE\.ssh\image-rec-key"
```

### Option B: ECR (For Frequent Deploys)

**One-time setup:**
```bash
cd infrastructure
chmod +x setup-ecr.sh
./setup-ecr.sh
```

**Then deploy:**
```bash
chmod +x deploy-ec2-ecr.sh
./deploy-ec2-ecr.sh ~/.ssh/image-rec-key
```

## Deployment Time Comparison

| Method | First Deploy | Subsequent Deploys |
|--------|--------------|-------------------|
| **Build on Server** | 10-15 min | 5-8 min |
| **ECR** | 15 min | 2-3 min |
| Direct SCP | 45+ min | 45+ min |
| SSM-based | Never works | N/A |

## Troubleshooting

### SSH Connection Refused

**Problem**: Can't connect via SSH
**Solutions**:
1. Check security group allows SSH from your IP:
   ```bash
   # Get your public IP
   curl https://checkip.amazonaws.com

   # Update security group if needed
   aws ec2 authorize-security-group-ingress \
     --group-id sg-xxxxx \
     --protocol tcp \
     --port 22 \
     --cidr YOUR_IP/32
   ```

2. Verify instance is running:
   ```bash
   aws ec2 describe-instances --instance-ids i-xxxxx
   ```

3. Check SSH key permissions:
   ```bash
   # On Linux/Mac
   chmod 600 ~/.ssh/image-rec-key
   ```

### Health Check Failed

**Problem**: Deployment completes but health check fails
**Solutions**:
1. Check service logs:
   ```bash
   ssh -i ~/.ssh/image-rec-key ec2-user@YOUR_IP \
     'sudo journalctl -u image-rec-backend -n 100'
   ```

2. Check Docker container:
   ```bash
   ssh -i ~/.ssh/image-rec-key ec2-user@YOUR_IP \
     'docker ps -a && docker logs image-rec-backend'
   ```

3. Verify database connectivity:
   ```bash
   ssh -i ~/.ssh/image-rec-key ec2-user@YOUR_IP \
     'sudo systemctl status image-rec-backend'
   ```

### Docker Build Fails

**Problem**: Docker image build fails locally
**Solutions**:
1. Check Docker is running:
   ```bash
   docker ps
   ```

2. Verify you're in the correct directory:
   ```bash
   ls ../backend/Dockerfile  # Should exist
   ```

3. Check for build errors in the output

## GitHub Actions Integration

To use SSH deployment in GitHub Actions, add your private key as a secret:

1. Go to repository Settings → Secrets and variables → Actions
2. Add new secret: `EC2_SSH_PRIVATE_KEY`
3. Paste your private key content
4. Update `.github/workflows/deploy-backend.yml` to use the simple deployment script

## Useful Commands

```bash
# SSH into server
ssh -i ~/.ssh/image-rec-key ec2-user@YOUR_IP

# View live logs
ssh -i ~/.ssh/image-rec-key ec2-user@YOUR_IP \
  'sudo journalctl -u image-rec-backend -f'

# Restart service
ssh -i ~/.ssh/image-rec-key ec2-user@YOUR_IP \
  'sudo systemctl restart image-rec-backend'

# Check service status
ssh -i ~/.ssh/image-rec-key ec2-user@YOUR_IP \
  'sudo systemctl status image-rec-backend'
```

## Security Notes

For beta testing, the current setup is fine. For production:

1. **Restrict SSH access**: Update security group to allow SSH only from your office IP
2. **Use bastion host**: Put EC2 in private subnet, access via bastion
3. **Rotate keys regularly**: Update SSH keys every 90 days
4. **Consider SSM**: For larger teams, SSM provides better audit logging

But for now, keep it simple!
