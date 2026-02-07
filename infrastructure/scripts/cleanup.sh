#!/bin/bash
set -e

# BigData Pipeline - AWS Infrastructure Cleanup Script
# ====================================================
# This script tears down all AWS resources to avoid unnecessary costs.
# WARNING: This is DESTRUCTIVE and CANNOT be undone. All data will be lost.
#
# Cost Savings: Removes ~$300-400/month in infrastructure costs
#   - EKS Control Plane: $73/month
#   - EC2 Nodes: $200-300/month
#   - EBS Volumes: $15-30/month
#   - S3 Storage: $2-50/month
#   - Data Transfer: $0-90/month

# Load environment
ENVIRONMENT=${1:-dev}
CONFIG_FILE="../../config/env.${ENVIRONMENT}.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    echo "Usage: ./cleanup.sh [dev|staging|prod]"
    exit 1
fi

source "$CONFIG_FILE"

echo "=========================================="
echo "AWS Infrastructure Cleanup Script"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Raw Data Bucket: $RAW_DATA_BUCKET"
echo "Processed Data Bucket: $PROCESSED_DATA_BUCKET"
echo ""
echo "⚠️  WARNING: This will DELETE all AWS resources and DATA CANNOT be recovered!"
echo ""

# Confirmation prompt
read -p "Type 'yes' to confirm cleanup: " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup process..."
echo ""

# Step 1: Delete EKS cluster and all associated resources
echo "Step 1/5: Deleting EKS cluster '$CLUSTER_NAME'..."
if eksctl get clusters --region $AWS_REGION | grep -q $CLUSTER_NAME; then
    eksctl delete cluster \
        --name $CLUSTER_NAME \
        --region $AWS_REGION \
        --force \
        --wait || true
    echo "✓ EKS cluster deleted"
else
    echo "✓ Cluster not found, skipping"
fi

# Step 2: Delete EC2 security groups (if not auto-deleted with cluster)
echo ""
echo "Step 2/5: Cleaning up security groups..."
# Find and delete security groups associated with the cluster
for sg_id in $(aws ec2 describe-security-groups \
    --region $AWS_REGION \
    --filters "Name=tag:aws:eks:cluster-name,Values=$CLUSTER_NAME" \
    --query 'SecurityGroups[*].GroupId' \
    --output text); do
    echo "Deleting security group: $sg_id"
    aws ec2 delete-security-group --group-id $sg_id --region $AWS_REGION || true
done
echo "✓ Security groups cleaned"

# Step 3: Delete Elastic IPs (if any)
echo ""
echo "Step 3/5: Cleaning up Elastic IPs..."
for alloc_id in $(aws ec2 describe-addresses \
    --region $AWS_REGION \
    --query 'Addresses[*].AllocationId' \
    --output text); do
    echo "Releasing Elastic IP: $alloc_id"
    aws ec2 release-address --allocation-id $alloc_id --region $AWS_REGION || true
done
echo "✓ Elastic IPs released"

# Step 4: Delete S3 buckets
echo ""
echo "Step 4/5: Deleting S3 buckets..."

# Empty and delete raw data bucket
if aws s3 ls s3://$RAW_DATA_BUCKET 2>/dev/null; then
    echo "Emptying bucket: s3://$RAW_DATA_BUCKET"
    aws s3 rm s3://$RAW_DATA_BUCKET --recursive || true
    echo "Deleting bucket: s3://$RAW_DATA_BUCKET"
    aws s3 rb s3://$RAW_DATA_BUCKET --force || true
    echo "✓ Raw data bucket deleted"
else
    echo "✓ Raw data bucket not found, skipping"
fi

# Empty and delete processed data bucket
if aws s3 ls s3://$PROCESSED_DATA_BUCKET 2>/dev/null; then
    echo "Emptying bucket: s3://$PROCESSED_DATA_BUCKET"
    aws s3 rm s3://$PROCESSED_DATA_BUCKET --recursive || true
    echo "Deleting bucket: s3://$PROCESSED_DATA_BUCKET"
    aws s3 rb s3://$PROCESSED_DATA_BUCKET --force || true
    echo "✓ Processed data bucket deleted"
else
    echo "✓ Processed data bucket not found, skipping"
fi

# Step 5: Delete IAM roles and policies
echo ""
echo "Step 5/5: Cleaning up IAM roles..."

# Get EC2 instance role associated with cluster nodes
NODE_ROLE_ARN=$(aws iam list-roles \
    --query "Roles[?contains(AssumeRolePolicyDocument, 'ec2.amazonaws.com')].Arn" \
    --output text | grep "eksctl" | head -1)

if [ ! -z "$NODE_ROLE_ARN" ]; then
    NODE_ROLE_NAME=$(echo $NODE_ROLE_ARN | awk -F'/' '{print $NF}')
    echo "Cleaning role: $NODE_ROLE_NAME"
    
    # Delete inline policies
    for policy_name in $(aws iam list-role-policies --role-name $NODE_ROLE_NAME --query 'PolicyNames' --output text); do
        echo "Deleting inline policy: $policy_name"
        aws iam delete-role-policy --role-name $NODE_ROLE_NAME --policy-name $policy_name || true
    done
    
    # Detach managed policies
    for policy_arn in $(aws iam list-attached-role-policies --role-name $NODE_ROLE_NAME --query 'AttachedPolicies[*].PolicyArn' --output text); do
        echo "Detaching policy: $policy_arn"
        aws iam detach-role-policy --role-name $NODE_ROLE_NAME --policy-arn $policy_arn || true
    done
    
    # Delete the role
    echo "Deleting role: $NODE_ROLE_NAME"
    aws iam delete-role --role-name $NODE_ROLE_NAME || true
    echo "✓ IAM roles cleaned"
else
    echo "✓ No cluster roles found, skipping"
fi

# Step 6: Delete CloudFormation stacks (if any remain)
echo ""
echo "Cleaning up CloudFormation stacks..."
for stack in $(aws cloudformation list-stacks \
    --region $AWS_REGION \
    --query "StackSummaries[?StackStatus!='DELETE_COMPLETE' && contains(StackName, '$CLUSTER_NAME')].StackName" \
    --output text); do
    echo "Deleting stack: $stack"
    aws cloudformation delete-stack --stack-name $stack --region $AWS_REGION || true
done
echo "✓ CloudFormation stacks cleaned"

echo ""
echo "=========================================="
echo "✓ Cleanup complete!"
echo "=========================================="
echo ""
echo "Cost impact:"
echo "  - Monthly savings: ~$300-400"
echo "  - Data recovery: NOT possible"
echo ""
echo "To redeploy infrastructure:"
echo "  make setup ENVIRONMENT=$ENVIRONMENT"
echo ""

