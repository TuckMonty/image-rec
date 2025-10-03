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

## 3. Configure GitHub Secrets

Go to: Repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCESS_KEY_ID` - From step 1
- `AWS_SECRET_ACCESS_KEY` - From step 1
- `REACT_APP_API_URL` - ALB DNS from terraform output

## 4. Update GitHub Actions Workflow Variables

Edit `.github/workflows/deploy-backend.yml`:
```yaml
env:
  ECR_REPOSITORY: image-rec-backend  # Should match terraform output
  ECS_SERVICE: image-rec-backend-service  # Should match terraform output
  ECS_CLUSTER: image-rec-cluster  # Should match terraform output
```

## 5. Push and Deploy

```bash
git add .
git commit -m "Setup automated deployment"
git push origin main
```

GitHub Actions will automatically build and deploy!

## 6. Verify Deployment

```bash
# Get ALB URL from terraform
terraform output alb_dns_name

# Test the backend
curl http://<alb-dns-name>/health
```

## Next Steps

- Setup custom domain with Route 53
- Configure HTTPS with ACM certificate
- Enable auto-scaling based on traffic
- Setup CloudWatch alarms

See full documentation in `docs/DEPLOYMENT.md`.
