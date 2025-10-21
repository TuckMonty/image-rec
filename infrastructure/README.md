# Infrastructure

This directory contains infrastructure code and deployment scripts for the Image Recognition app.

## Contents

- **terraform/** - Infrastructure as Code (Terraform) for AWS resources
- **deploy.sh** - Deployment script for Linux/Mac
- **deploy.ps1** - Deployment script for Windows

## Deployment Scripts

The deployment scripts (`deploy.sh` and `deploy.ps1`) automate the process of building and deploying the backend Docker image to AWS ECR.

### When to Use

1. **Initial Setup (Required)**: After running `terraform apply` for the first time, you MUST run the deployment script to push the initial Docker image to ECR. Without this, ECS cannot start your service.

2. **Manual Deployments (Optional)**: Use these scripts anytime you want to manually deploy changes without going through GitHub Actions.

### What the Scripts Do

1. Build the backend Docker image from `backend/Dockerfile`
2. Authenticate Docker with AWS ECR
3. Tag the image with the git commit hash and `latest`
4. Push the image to ECR
5. Trigger ECS to redeploy the service with the new image

### Usage

**Windows:**
```powershell
.\deploy.ps1
```

**Linux/Mac:**
```bash
chmod +x deploy.sh
./deploy.sh
```

### Requirements

- Docker installed and running
- AWS CLI installed and configured with valid credentials
- Git (for tagging images with commit hash)
- Terraform infrastructure already deployed

## Terraform

See `terraform/README.md` for detailed information about the infrastructure setup.

## Automated CI/CD

After initial setup, GitHub Actions handles automated deployments:
- `.github/workflows/deploy-backend.yml` - Deploys backend on push to `main`
- `.github/workflows/deploy-frontend.yml` - Deploys frontend on push to `main`

The deployment scripts in this directory are only needed for:
1. Initial setup after `terraform apply`
2. Manual deployments when you don't want to push to GitHub

See `docs/DEPLOYMENT.md` for complete deployment documentation.
