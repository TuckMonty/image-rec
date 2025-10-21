# Terraform Infrastructure

This directory contains Terraform configuration for deploying the Image Recognition app infrastructure on AWS.

## What Gets Created

Running `terraform apply` creates:

### Networking
- VPC with public and private subnets across 2 availability zones
- Internet Gateway for public internet access
- Route tables and subnet associations
- Security groups for ALB, ECS tasks, and RDS

### Compute
- ECS Cluster (Fargate)
- ECS Service and Task Definition for backend
- Application Load Balancer (ALB) with target groups
- CloudWatch Log Groups for container logs

### Storage & Database
- ECR repositories for backend and frontend Docker images
- RDS PostgreSQL instance in private subnet
- S3 bucket for image storage with versioning enabled

### Security
- IAM roles for ECS task execution and application permissions
- Secrets Manager for storing database credentials and S3 bucket name
- Security groups with least-privilege access

## Usage

### Initial Setup

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your values:**
   ```hcl
   aws_region     = "us-east-1"
   project_name   = "image-rec"
   environment    = "production"
   db_password    = "your-secure-password-here"  # Use a strong password!
   s3_bucket_name = "image-rec-backend-unique"   # Must be globally unique
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Review the plan:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

6. **Save the outputs:**
   ```bash
   terraform output > outputs.txt
   ```

### IMPORTANT: Post-Deployment Step

**After running `terraform apply`, you MUST build and push the Docker image to ECR:**

```powershell
# Windows
cd ..
.\deploy.ps1

# Linux/Mac
cd ..
chmod +x deploy.sh
./deploy.sh
```

Without this step, ECS will fail with: `CannotPullContainerError: image not found`

This is because Terraform creates the ECR repository, but you need to push an actual Docker image to it before ECS can pull and run it.

## Outputs

After applying, you'll get:

- `ecr_backend_repository_url` - ECR URL for backend images
- `ecr_frontend_repository_url` - ECR URL for frontend images
- `alb_dns_name` - Load balancer URL to access your backend
- `ecs_cluster_name` - ECS cluster name
- `ecs_service_name` - ECS service name
- `rds_endpoint` - Database endpoint (sensitive)
- `s3_bucket_name` - S3 bucket for images

Save these for GitHub Secrets configuration.

## Making Changes

To update infrastructure:

1. Edit `main.tf`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

## Destroying Infrastructure

To tear down all resources:

```bash
terraform destroy
```

**Warning:** This will delete your database and S3 bucket. Make backups first!

## Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `aws_region` | AWS region | No | `us-east-1` |
| `project_name` | Project name (used for resource naming) | No | `image-rec` |
| `environment` | Environment name | No | `production` |
| `db_password` | RDS database password | Yes | - |
| `s3_bucket_name` | S3 bucket name (must be globally unique) | No | `image-rec-backend` |

## State Management

Currently using local state. For production, consider:
- Using S3 backend for state storage
- Enabling state locking with DynamoDB
- Using Terraform Cloud/Enterprise

See [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/index.html) for details.

## Security Notes

- **Never commit `terraform.tfvars` to git** - it contains sensitive passwords
- Database is in private subnet with no public access
- Security groups follow least-privilege principle
- All secrets stored in AWS Secrets Manager
- IAM roles have minimal required permissions

## Troubleshooting

### ECS Service Not Starting

**Error:** `CannotPullContainerError: image not found`
- **Solution:** Run the deployment script to push Docker image to ECR (see above)

### State Lock Errors

- Delete `.terraform.lock.hcl` and run `terraform init` again

### Resource Already Exists

- Check if resources were created outside Terraform
- Import existing resources: `terraform import <resource_type>.<name> <id>`

## Cost Estimate

Running this infrastructure costs approximately:
- ECS Fargate: ~$15-30/month (0.25 vCPU, 0.5 GB RAM)
- RDS db.t3.micro: ~$15/month
- ALB: ~$16/month + data transfer
- ECR/S3: Minimal (pay per usage)

**Total: ~$50-70/month**

Use `terraform destroy` when not in use to avoid charges.
