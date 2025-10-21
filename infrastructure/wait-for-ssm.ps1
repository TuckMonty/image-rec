# Wait for SSM Agent to be ready
# This script checks if the SSM agent is online and ready for connections

$INSTANCE_ID = "i-092e3282281d52c9a"
$AWS_REGION = "us-east-1"
$MAX_WAIT_MINUTES = 10

Write-Host "Waiting for SSM agent to be ready on instance $INSTANCE_ID..." -ForegroundColor Yellow
Write-Host "This typically takes 5-10 minutes after instance creation." -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date
$timeout = $startTime.AddMinutes($MAX_WAIT_MINUTES)

while ((Get-Date) -lt $timeout) {
    try {
        $status = aws ssm describe-instance-information `
            --filters "Key=InstanceIds,Values=$INSTANCE_ID" `
            --region $AWS_REGION `
            --query "InstanceInformationList[0].PingStatus" `
            --output text 2>$null

        if ($status -eq "Online") {
            Write-Host "`n✓ SSM agent is online and ready!" -ForegroundColor Green
            Write-Host "You can now run the deployment script: .\deploy-ec2.ps1" -ForegroundColor Green
            exit 0
        }

        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
        Write-Host "Still waiting... ($elapsed minutes elapsed, status: $status)" -ForegroundColor Yellow
        Start-Sleep -Seconds 30
    }
    catch {
        Write-Host "Checking..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
    }
}

Write-Host "`nTimeout reached. SSM agent is not responding." -ForegroundColor Red
Write-Host "Please check:" -ForegroundColor Yellow
Write-Host "1. Instance is running: aws ec2 describe-instances --instance-ids $INSTANCE_ID" -ForegroundColor Yellow
Write-Host "2. Instance has IAM role attached: Check Terraform outputs" -ForegroundColor Yellow
Write-Host "3. Check user data logs via SSH if you have a key configured" -ForegroundColor Yellow
exit 1
