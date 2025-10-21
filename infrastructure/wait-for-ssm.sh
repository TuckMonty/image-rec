#!/bin/bash
# Wait for SSM Agent to be ready
# This script checks if the SSM agent is online and ready for connections

INSTANCE_ID="i-092e3282281d52c9a"
AWS_REGION="us-east-1"
MAX_WAIT_MINUTES=10

echo -e "\033[1;33mWaiting for SSM agent to be ready on instance $INSTANCE_ID...\033[0m"
echo -e "\033[1;33mThis typically takes 5-10 minutes after instance creation.\033[0m"
echo ""

START_TIME=$(date +%s)
TIMEOUT=$((START_TIME + MAX_WAIT_MINUTES * 60))

while [ $(date +%s) -lt $TIMEOUT ]; do
    STATUS=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
        --region $AWS_REGION \
        --query "InstanceInformationList[0].PingStatus" \
        --output text 2>/dev/null || echo "Unknown")

    if [ "$STATUS" = "Online" ]; then
        echo -e "\n\033[0;32m✓ SSM agent is online and ready!\033[0m"
        echo -e "\033[0;32mYou can now run the deployment script: ./deploy-ec2.sh\033[0m"
        exit 0
    fi

    ELAPSED=$(( ($(date +%s) - START_TIME) / 60 ))
    echo -e "\033[1;33mStill waiting... ($ELAPSED minutes elapsed, status: $STATUS)\033[0m"
    sleep 30
done

echo -e "\n\033[0;31mTimeout reached. SSM agent is not responding.\033[0m"
echo -e "\033[1;33mPlease check:\033[0m"
echo -e "\033[1;33m1. Instance is running: aws ec2 describe-instances --instance-ids $INSTANCE_ID\033[0m"
echo -e "\033[1;33m2. Instance has IAM role attached: Check Terraform outputs\033[0m"
echo -e "\033[1;33m3. Check user data logs via SSH if you have a key configured\033[0m"
exit 1
