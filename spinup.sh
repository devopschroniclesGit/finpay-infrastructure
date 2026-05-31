#!/bin/bash
set -e

echo "=== FinPay Environment Spin Up ==="
echo ""

# Step 1 — Clock sync
echo "1. Syncing VM clock..."
sudo chronyc makestep
echo "   Done"

# Step 2 — Get instance details
echo "2. Getting EB instance details..."
INSTANCE_ID=$(aws elasticbeanstalk describe-environment-resources \
  --environment-name finpay-production \
  --region us-east-1 \
  --query 'EnvironmentResources.Instances[0].Id' \
  --output text)
echo "   Instance: $INSTANCE_ID"

EB_SG=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region us-east-1 \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)
echo "   EB SG: $EB_SG"

ALB_SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=finpay-production-alb-sg \
  --region us-east-1 \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
echo "   ALB SG: $ALB_SG"

# Step 3 — Security group rule
echo "3. Adding ALB→EB security group rule..."
aws ec2 authorize-security-group-ingress \
  --group-id $EB_SG \
  --protocol tcp \
  --port 80 \
  --source-group $ALB_SG \
  --region us-east-1 2>/dev/null || echo "   Rule may already exist, continuing..."

# Step 4 — Register target
echo "4. Registering EB instance in ALB target group..."
TG_ARN=$(aws elbv2 describe-target-groups \
  --names finpay-tg \
  --region us-east-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$INSTANCE_ID,Port=80 \
  --region us-east-1

echo "   Registered. Waiting 45s for health check..."
sleep 45

# Step 5 — Verify health
echo "5. Checking target health..."
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

# Step 6 — Cloudflare reminder
echo ""
echo "=== MANUAL STEP REQUIRED ==="
echo "Update Cloudflare DNS:"
echo "  Type:  CNAME"
echo "  Name:  finpay"
echo "  Value: $(cd ~/finpay-infrastructure && terraform output -raw cloudfront_domain)"
echo "  Proxy: DNS only (grey cloud)"
echo ""

# Step 7 — Trigger pipeline
echo "6. Triggering CI/CD pipeline..."
cd ~/finpay-api
git commit --allow-empty -m "chore: trigger pipeline after environment redeploy"
git push
echo "   Pipeline triggered. Check CodePipeline console (~5-8 min)"
echo ""
echo "=== Spin up complete ==="
echo "Verify: curl -I https://finpay.devopschronicles.com/api/v1/health"

