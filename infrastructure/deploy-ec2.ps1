# EC2 Backend Deployment Script for Windows
#
# This script builds the backend Docker image and deploys it to EC2.
# It must be run ONCE after initial terraform apply.
# After that, this script or GitHub Actions can be used for deployments.
#
# Usage: .\deploy-ec2.ps1
# Requirements: Docker, AWS CLI, Git

# Exit on any error
$ErrorActionPreference = "Stop"

# Configuration
$AWS_REGION = "us-east-1"
$PROJECT_NAME = "image-rec"

Write-Host "Starting EC2 deployment process..." -ForegroundColor Green

# Step 1: Get EC2 instance ID and IP from Terraform
Write-Host "`nStep 1: Getting EC2 instance information..." -ForegroundColor Yellow
Set-Location -Path "terraform"
try {
    $INSTANCE_ID = terraform output -raw instance_id
    $EC2_IP = terraform output -raw ec2_public_ip
} catch {
    Write-Host "Error: Could not get EC2 instance information from Terraform outputs" -ForegroundColor Red
    Write-Host "Make sure you have run 'terraform apply' first"
    exit 1
}
Set-Location -Path ".."

if ([string]::IsNullOrEmpty($INSTANCE_ID) -or [string]::IsNullOrEmpty($EC2_IP)) {
    Write-Host "Error: Could not get EC2 instance information" -ForegroundColor Red
    exit 1
}

Write-Host "Instance ID: $INSTANCE_ID"
Write-Host "Instance IP: $EC2_IP"

# Step 2: Build the Docker image
Write-Host "`nStep 2: Building Docker image..." -ForegroundColor Yellow
Set-Location -Path "..\backend"
try {
    $IMAGE_TAG = git rev-parse --short HEAD
} catch {
    $IMAGE_TAG = "local-$(Get-Date -Format 'yyyyMMddHHmmss')"
}

docker build -t "image-rec-backend:$IMAGE_TAG" .
docker tag "image-rec-backend:$IMAGE_TAG" "image-rec-backend:latest"

# Step 3: Save Docker image to tar file
Write-Host "`nStep 3: Saving Docker image..." -ForegroundColor Yellow
$TempPath = "$env:TEMP\image-rec-backend.tar.gz"
docker save image-rec-backend:latest | gzip > $TempPath

# Step 4: Check if instance is ready
Write-Host "`nStep 4: Checking if EC2 instance is ready..." -ForegroundColor Yellow
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
Write-Host "Instance is running"

# Step 5: Wait for SSM agent to be ready
Write-Host "`nStep 5: Waiting for SSM agent to be ready..." -ForegroundColor Yellow
Write-Host "This typically takes 5-10 minutes after instance creation."
Write-Host "Checking SSM agent status every 30 seconds..."

$MAX_ATTEMPTS = 20  # 20 attempts * 30 seconds = 10 minutes
$ATTEMPT = 0
$SSM_STATUS = "NotAvailable"

while ($ATTEMPT -lt $MAX_ATTEMPTS) {
    try {
        $SSM_STATUS = aws ssm describe-instance-information `
            --filters "Key=InstanceIds,Values=$INSTANCE_ID" `
            --region $AWS_REGION `
            --query "InstanceInformationList[0].PingStatus" `
            --output text 2>$null
    } catch {
        $SSM_STATUS = "NotAvailable"
    }

    if ($SSM_STATUS -eq "Online") {
        Write-Host "✓ SSM agent is online!" -ForegroundColor Green
        break
    }

    $ATTEMPT++
    Write-Host "Attempt $ATTEMPT/$MAX_ATTEMPTS`: SSM status is '$SSM_STATUS', waiting..."
    Start-Sleep -Seconds 30
}

# Step 6: Copy image to EC2 using AWS Systems Manager
Write-Host "`nStep 6: Copying Docker image to EC2..." -ForegroundColor Yellow

if ($SSM_STATUS -eq "Online") {
    Write-Host "Using AWS Systems Manager to deploy..."

    # Upload to S3 temporarily
    $TEMP_BUCKET = "$PROJECT_NAME-deploy-temp-$(Get-Random)"
    aws s3 mb "s3://$TEMP_BUCKET" --region $AWS_REGION
    aws s3 cp $TempPath "s3://$TEMP_BUCKET/image-rec-backend.tar.gz"

    # Download and load on EC2 via SSM
    $commands = @"
aws s3 cp s3://$TEMP_BUCKET/image-rec-backend.tar.gz /tmp/image-rec-backend.tar.gz
docker load < /tmp/image-rec-backend.tar.gz
rm /tmp/image-rec-backend.tar.gz
docker stop image-rec-backend 2>/dev/null || true
docker rm image-rec-backend 2>/dev/null || true
systemctl daemon-reload
systemctl enable image-rec-backend
systemctl restart image-rec-backend
sleep 5
systemctl status image-rec-backend
"@

    $COMMAND_ID = aws ssm send-command `
        --instance-ids $INSTANCE_ID `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=[$($commands -replace "`n", "," -replace '"', '\"')]" `
        --region $AWS_REGION `
        --query "Command.CommandId" `
        --output text

    Write-Host "Waiting for deployment to complete..."
    aws ssm wait command-executed --command-id $COMMAND_ID --instance-id $INSTANCE_ID --region $AWS_REGION

    # Clean up S3 bucket
    aws s3 rb "s3://$TEMP_BUCKET" --force

} else {
    Write-Host "SSM not available. Please ensure:" -ForegroundColor Yellow
    Write-Host "1. EC2 instance has SSM agent installed (should be automatic on Amazon Linux 2023)"
    Write-Host "2. Instance has IAM role with SSM permissions"
    Write-Host "3. Instance has been running for at least 5 minutes"
    Write-Host ""
    Write-Host "Alternative: Deploy via SSH" -ForegroundColor Yellow
    Write-Host "If you have SSH access configured, run:"
    Write-Host "  scp $TempPath ec2-user@${EC2_IP}:/tmp/"
    Write-Host "  ssh ec2-user@$EC2_IP 'docker load < /tmp/image-rec-backend.tar.gz && systemctl restart image-rec-backend'"
    exit 1
}

# Clean up local tar file
Remove-Item $TempPath

Write-Host "`n✓ Deployment successful!" -ForegroundColor Green
Write-Host "Backend URL: http://${EC2_IP}:8000"
Write-Host "`nTest the deployment:"
Write-Host "  curl http://${EC2_IP}:8000/health" -ForegroundColor Cyan
