# Simple SSH-Based EC2 Deployment Script for Windows
#
# This script deploys the backend to EC2 using SSH (no SSM required)
# Much simpler and more reliable for small/beta applications
#
# Prerequisites:
# 1. SSH key configured in terraform (ssh_key_name variable)
# 2. Private key available locally (default: ~/.ssh/id_rsa)
# 3. Docker Desktop running on Windows
# 4. OpenSSH client installed (built into Windows 10+)
#
# Usage: .\deploy-ec2-simple.ps1 [-SshKeyPath "C:\path\to\key.pem"]
#

param(
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
)

$ErrorActionPreference = "Stop"

# Configuration
$AWS_REGION = "us-east-1"
$PROJECT_NAME = "image-rec"
$SSH_USER = "ec2-user"
$TEMP_IMAGE = "$env:TEMP\image-rec-backend.tar.gz"

Write-Host "=== Simple EC2 Deployment ===" -ForegroundColor Green
Write-Host ""

# Validate SSH key exists
if (-not (Test-Path $SshKeyPath)) {
    Write-Host "Error: SSH key not found at $SshKeyPath" -ForegroundColor Red
    Write-Host "Please provide the path to your private key:"
    Write-Host '  .\deploy-ec2-simple.ps1 -SshKeyPath "C:\path\to\your\key.pem"'
    exit 1
}

# Step 1: Get EC2 IP from Terraform
Write-Host "Step 1: Getting EC2 instance IP..." -ForegroundColor Yellow
Push-Location terraform
try {
    $EC2_IP = terraform output -raw ec2_public_ip 2>$null
    $INSTANCE_ID = terraform output -raw instance_id 2>$null
} finally {
    Pop-Location
}

if ([string]::IsNullOrEmpty($EC2_IP)) {
    Write-Host "Error: Could not get EC2 IP from Terraform" -ForegroundColor Red
    Write-Host "Make sure you have run 'terraform apply' first"
    exit 1
}

Write-Host "Instance ID: $INSTANCE_ID"
Write-Host "Instance IP: $EC2_IP"

# Step 2: Wait for instance to be running
Write-Host "`nStep 2: Waiting for EC2 instance to be ready..." -ForegroundColor Yellow
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
Write-Host "Instance is running"

# Wait for SSH to be available
Write-Host "Waiting for SSH to be available..."
$MAX_ATTEMPTS = 30
$ATTEMPT = 0
$SSH_READY = $false

while ($ATTEMPT -lt $MAX_ATTEMPTS) {
    try {
        $result = ssh -i "$SshKeyPath" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${SSH_USER}@${EC2_IP}" "echo 'SSH ready'" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ SSH connection successful" -ForegroundColor Green
            $SSH_READY = $true
            break
        }
    } catch {}

    $ATTEMPT++
    Write-Host "Attempt $ATTEMPT/$MAX_ATTEMPTS : Waiting for SSH..."
    Start-Sleep -Seconds 10
}

if (-not $SSH_READY) {
    Write-Host "Error: SSH connection timeout" -ForegroundColor Red
    Write-Host "Please check:"
    Write-Host "1. Security group allows SSH from your IP"
    Write-Host "2. SSH key is correct"
    Write-Host "3. Instance is fully booted"
    exit 1
}

# Step 3: Build Docker image
Write-Host "`nStep 3: Building Docker image..." -ForegroundColor Yellow
Push-Location ..\backend
try {
    $IMAGE_TAG = (git rev-parse --short HEAD 2>$null)
    if ([string]::IsNullOrEmpty($IMAGE_TAG)) {
        $IMAGE_TAG = "local-$(Get-Date -Format 'yyyyMMddHHmmss')"
    }

    docker build -t "image-rec-backend:$IMAGE_TAG" .
    docker tag "image-rec-backend:$IMAGE_TAG" image-rec-backend:latest
} finally {
    Pop-Location
}

# Step 4: Save and compress Docker image
Write-Host "`nStep 4: Saving Docker image..." -ForegroundColor Yellow
docker save image-rec-backend:latest | gzip > $TEMP_IMAGE
$IMAGE_SIZE = (Get-Item $TEMP_IMAGE).Length / 1MB
Write-Host "Image size: $([math]::Round($IMAGE_SIZE, 2)) MB"

# Step 5: Copy image to EC2
Write-Host "`nStep 5: Copying image to EC2 (this may take a few minutes)..." -ForegroundColor Yellow
scp -i "$SshKeyPath" -o StrictHostKeyChecking=no "$TEMP_IMAGE" "${SSH_USER}@${EC2_IP}:/tmp/image-rec-backend.tar.gz"

# Step 6: Load and start container on EC2
Write-Host "`nStep 6: Deploying on EC2..." -ForegroundColor Yellow
$deployScript = @'
set -e
echo "Loading Docker image..."
docker load < /tmp/image-rec-backend.tar.gz

echo "Stopping existing container (if any)..."
docker stop image-rec-backend 2>/dev/null || true
docker rm image-rec-backend 2>/dev/null || true

echo "Reloading systemd and restarting service..."
sudo systemctl daemon-reload
sudo systemctl enable image-rec-backend
sudo systemctl restart image-rec-backend

echo "Waiting for service to start..."
sleep 5

echo "Service status:"
sudo systemctl status image-rec-backend --no-pager || true

echo "Cleaning up temporary files..."
rm /tmp/image-rec-backend.tar.gz
'@

ssh -i "$SshKeyPath" -o StrictHostKeyChecking=no "${SSH_USER}@${EC2_IP}" $deployScript

# Clean up local tar file
Remove-Item $TEMP_IMAGE -Force

# Step 7: Health check
Write-Host "`nStep 7: Running health check..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

try {
    $response = Invoke-WebRequest -Uri "http://${EC2_IP}:8000/health" -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ Health check passed!" -ForegroundColor Green
    }
} catch {
    Write-Host "Warning: Health check failed. Service may still be starting..." -ForegroundColor Yellow
    Write-Host "Check logs with: ssh -i `"$SshKeyPath`" ${SSH_USER}@${EC2_IP} 'sudo journalctl -u image-rec-backend -n 50'"
}

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Backend URL: http://${EC2_IP}:8000"
Write-Host "`nUseful commands:"
Write-Host "  Test API:        curl http://${EC2_IP}:8000/health"
Write-Host "  SSH to server:   ssh -i `"$SshKeyPath`" ${SSH_USER}@${EC2_IP}"
Write-Host "  View logs:       ssh -i `"$SshKeyPath`" ${SSH_USER}@${EC2_IP} 'sudo journalctl -u image-rec-backend -f'"
Write-Host "  Check status:    ssh -i `"$SshKeyPath`" ${SSH_USER}@${EC2_IP} 'sudo systemctl status image-rec-backend'"
