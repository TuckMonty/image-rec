# Quick Start - Automated Deployment Setup

This is a condensed guide to get your automated deployment pipeline running quickly.

## 1. Rotate Exposed Credentials (URGENT)

Your AWS credentials and database password were committed to git. You must:

1. **Rotate AWS credentials:**
   ```bash
   # Delete old access key from AWS Console or CLI
   aws iam delete-access-key --access-key-id AKIARCJ5UQ7VPPFBZANL --user-name <your-user>

   # Create new access key
   aws iam create-access-key --user-name <your-user>
   ```

2. **Change RDS password:**
   ```bash
   aws rds modify-db-instance \
     --db-instance-identifier image-rec-db \
     --master-user-password <new-secure-password> \
     --apply-immediately
   ```

## 2. Deploy AWS Infrastructure

```bash
cd infrastructure/terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars

# Deploy
terraform init
terraform apply
```

Save the outputs - you'll need them for GitHub Secrets.

## 3. Deploy Initial Docker Image to EC2

**CRITICAL**: You must deploy the initial Docker image to EC2 after Terraform creates the infrastructure.

**On Windows:**
```powershell
cd ../  # Go to infrastructure directory
.\deploy-ec2.ps1
```

**On Linux/Mac:**
```bash
cd ../  # Go to infrastructure directory
chmod +x deploy-ec2.sh
./deploy-ec2.sh
```

This script will:
- Build your backend Docker image
- Save it as a tar file
- Transfer it to EC2 via AWS Systems Manager
- Load and run the image on EC2
- Start the backend service

**Note**: This only needs to be done once. Future deployments are automated via GitHub Actions.

## 4. Configure GitHub Secrets

Go to: Repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCESS_KEY_ID` - Your new AWS access key from step 1
- `AWS_SECRET_ACCESS_KEY` - Your new AWS secret key from step 1
- `REACT_APP_API_URL` - EC2 backend URL from terraform output (e.g., `http://44.200.123.45:8000`)

## 5. Push and Deploy (Automated)

```bash
git add .
git commit -m "Setup automated deployment"
git push origin main
```

GitHub Actions will automatically build and deploy to EC2!

## 6. Verify Deployment

```bash
# Get EC2 IP from terraform
terraform output ec2_public_ip

# Test the backend
curl http://<ec2-ip>:8000/health
```

## Next Steps

- Setup custom domain with Route 53
- Configure HTTPS with Nginx reverse proxy or ALB
- Setup CloudWatch alarms for monitoring
- Configure automated backups for RDS

See full documentation in `docs/DEPLOYMENT.md`.
