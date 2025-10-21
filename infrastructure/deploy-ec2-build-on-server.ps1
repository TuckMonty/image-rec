# Build-on-Server Deployment Script for Windows
#
# This script transfers only the source code to EC2 and builds the Docker image there.
# Perfect for large images (ML/AI apps) where uploading the built image takes too long.
#
# First deployment: ~10-15 minutes (building on server)
# Subsequent deploys: ~5-8 minutes (Docker layer caching)
#
# Usage: .\deploy-ec2-build-on-server.ps1 [-SshKeyPath "C:\path\to\key.pem"]
#

param(
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\image-rec-key"
)

$ErrorActionPreference = "Stop"

# Configuration
$AWS_REGION = "us-east-1"
$PROJECT_NAME = "image-rec"
$SSH_USER = "ec2-user"
$TEMP_SOURCE = "$env:TEMP\backend-source.tar.gz"

Write-Host "=== Build-on-Server EC2 Deployment ===" -ForegroundColor Green
Write-Host ""

# Validate SSH key exists
if (-not (Test-Path $SshKeyPath)) {
    Write-Host "Error: SSH key not found at $SshKeyPath" -ForegroundColor Red
    Write-Host 'Please provide the path to your private key:'
    Write-Host '  .\deploy-ec2-build-on-server.ps1 -SshKeyPath "C:\path\to\your\key.pem"'
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

# Step 2: Wait for instance to be ready
Write-Host "`nStep 2: Waiting for EC2 instance to be ready..." -ForegroundColor Yellow
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
Write-Host "Instance is running"

# Remove old SSH host key if it exists (happens when instance is recreated)
Write-Host "Removing old SSH host key (if any)..."
ssh-keygen -R $EC2_IP 2>$null

# Wait for SSH
Write-Host "Waiting for SSH to be available..."
$MAX_ATTEMPTS = 30
$ATTEMPT = 0
$SSH_READY = $false

while ($ATTEMPT -lt $MAX_ATTEMPTS) {
    try {
        $result = ssh -i "$SshKeyPath" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "${SSH_USER}@${EC2_IP}" "echo 'SSH ready'" 2>$null
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
    exit 1
}

# Step 3: Create tarball of backend source
Write-Host "`nStep 3: Packaging backend source code..." -ForegroundColor Yellow
Push-Location ..\backend
try {
    # Use tar (built into Windows 10+) to create archive
    tar -czf $TEMP_SOURCE `
        --exclude='__pycache__' `
        --exclude='*.pyc' `
        --exclude='.pytest_cache' `
        --exclude='venv' `
        --exclude='.env' `
        Dockerfile requirements.txt src/

    $SOURCE_SIZE = (Get-Item $TEMP_SOURCE).Length / 1KB
    Write-Host "Source package size: $([math]::Round($SOURCE_SIZE, 2)) KB (vs ~6GB for full Docker image!)"
} finally {
    Pop-Location
}

# Step 4: Copy source to EC2
Write-Host "`nStep 4: Copying source to EC2 (~10 seconds)..." -ForegroundColor Yellow
scp -i "$SshKeyPath" -o StrictHostKeyChecking=accept-new "$TEMP_SOURCE" "${SSH_USER}@${EC2_IP}:/tmp/backend-source.tar.gz"

# Clean up local tarball
Remove-Item $TEMP_SOURCE -Force

# Step 5: Build and deploy on EC2
Write-Host "`nStep 5: Building Docker image on EC2..." -ForegroundColor Yellow
Write-Host "This will take ~10-15 minutes on first deploy (downloading PyTorch, etc.)"
Write-Host "Subsequent deploys will be faster due to Docker layer caching."
Write-Host ""

$IMAGE_TAG = (git rev-parse --short HEAD 2>$null)
if ([string]::IsNullOrEmpty($IMAGE_TAG)) {
    $IMAGE_TAG = "local-$(Get-Date -Format 'yyyyMMddHHmmss')"
}

$buildScript = @"
set -e

# Check disk space and cleanup if needed
echo "Checking disk space..."
AVAILABLE_GB=`$(df / --output=avail | tail -1 | awk '{print int(`$1/1024/1024)}')
echo "Available space: `${AVAILABLE_GB}GB"

if [ `$AVAILABLE_GB -lt 15 ]; then
  echo "Warning: Low disk space. Cleaning up old Docker images..."
  docker image prune -a -f || true
  docker system prune -f || true
  echo "Space after cleanup: `$(df -h / | grep '/$' | awk '{print `$4}')"
fi

# Extract source
echo "Extracting source code..."
mkdir -p /tmp/backend-build
cd /tmp/backend-build
tar -xzf /tmp/backend-source.tar.gz
rm /tmp/backend-source.tar.gz

# Build Docker image
echo "Building Docker image (please wait, this takes time on first build)..."
docker build -t image-rec-backend:${IMAGE_TAG} .
docker tag image-rec-backend:${IMAGE_TAG} image-rec-backend:latest

# Clean up source
cd /
rm -rf /tmp/backend-build

# Deploy
echo "Stopping existing container..."
docker stop image-rec-backend 2>/dev/null || true
docker rm image-rec-backend 2>/dev/null || true

echo "Starting new container..."
sudo systemctl daemon-reload
sudo systemctl enable image-rec-backend
sudo systemctl restart image-rec-backend

echo "Waiting for service to start..."
sleep 5

sudo systemctl status image-rec-backend --no-pager || true

# Clean up old Docker images (keep only latest)
echo "Cleaning up old Docker images..."
docker image prune -f || true
echo "Final disk space: `$(df -h / | grep '/$' | awk '{print `$4}')"
"@

ssh -i "$SshKeyPath" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${EC2_IP}" $buildScript

# Step 6: Health check
Write-Host "`nStep 6: Running health check..." -ForegroundColor Yellow
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
Write-Host "`nDeployment stats:"
Write-Host "  - First deploy: ~10-15 minutes (building ML dependencies)"
Write-Host "  - Next deploys: ~5-8 minutes (Docker cache)"
Write-Host "  - vs SCP method: 45+ minutes every time!"
Write-Host "`nUseful commands:"
Write-Host "  SSH to server:   ssh -i `"$SshKeyPath`" ${SSH_USER}@${EC2_IP}"
Write-Host "  View logs:       ssh -i `"$SshKeyPath`" ${SSH_USER}@${EC2_IP} 'sudo journalctl -u image-rec-backend -f'"
