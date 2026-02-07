# Infrastructure Setup Guide

Complete guide for setting up the EKS infrastructure required to run the BigData Pipeline.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Automated Setup (Recommended)](#automated-setup-recommended)
4. [Manual Setup](#manual-setup)
5. [Cost Estimation](#cost-estimation)
6. [Cleanup](#cleanup)
7. [Troubleshooting](#troubleshooting)

---

## Overview

This guide sets up:

- **Amazon EKS Cluster** - Kubernetes cluster for orchestration
- **EC2 Nodes** - 3 m5.xlarge worker nodes
- **S3 Buckets** - Data storage (raw and processed)
- **IAM Roles** - Service account permissions
- **Spark Operator** - Kubernetes operator for Spark jobs

**Setup Time:** ~20-30 minutes
**Estimated Cost:** ~$565/month (see [Cost Estimation](#cost-estimation))

---

## Prerequisites

### AWS Account

- AWS account with appropriate permissions
- AWS CLI v2 installed and configured
- IAM user/role with EC2, EKS, S3, and IAM permissions

```bash
# Verify AWS access
aws sts get-caller-identity
aws ec2 describe-account-attributes
```

### Local Tools

```bash
# Required
aws --version              # AWS CLI v2
eksctl version             # EKS management
helm version               # Kubernetes package manager
kubectl version --client   # Kubernetes CLI

# Optional (for manual setup)
docker --version           # For local testing
```

### Installation

```bash
# macOS (using Homebrew)
brew install awscli eksctl helm kubectl

# Ubuntu/Debian
sudo apt-get install awscli eksctl helm kubectl

# Verify installation
aws --version && eksctl version && helm version && kubectl version --client
```

---

## Automated Setup (Recommended)

### Quick Start

```bash
cd /Users/yfrimpong/DevOps/BigDataPipeline

# Load environment
source config/env.dev.sh

# Run setup (interactive, shows progress)
make setup
```

### What Gets Created

```bash
# The setup script automatically:
# 1. Creates EKS cluster (3 nodes, m5.xlarge)
# 2. Creates S3 buckets for data
# 3. Installs Spark Operator via Helm
# 4. Configures IAM roles for S3 access
# 5. Sets up kubeconfig for local access
```

### Verification

```bash
# Verify cluster created
eksctl get clusters

# Check nodes
kubectl get nodes

# Check Spark Operator
kubectl get pods -n spark-operator

# List S3 buckets
aws s3 ls | grep yawbdata
```

---

## Manual Setup

If you prefer step-by-step control, follow these steps:

### Step 1: Create SSH Key Pair (Optional)

```bash
# Generate SSH key for EC2 access (optional)
aws ec2 create-key-pair \
  --key-name bigdata-key \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/bigdata-key.pem

chmod 400 ~/.ssh/bigdata-key.pem
```

### Step 2: Create EKS Cluster

```bash
# Load configuration
source config/env.dev.sh

# Create cluster (takes ~15 minutes)
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --nodegroup-name workers \
  --node-type m5.xlarge \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 10 \
  --with-oidc \
  --enable-ssm \
  --ssh-access \
  --ssh-public-key ~/.ssh/bigdata-key.pub

# Wait for completion (shows: [✓] EKS cluster resources in ... created)
```

### Step 3: Configure kubectl

```bash
# Update kubeconfig (eksctl does this automatically)
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $AWS_REGION

# Verify access
kubectl cluster-info
kubectl get nodes
```

### Step 4: Create S3 Buckets

```bash
# Load configuration
source config/env.dev.sh

# Create raw data bucket
aws s3 mb s3://$RAW_DATA_BUCKET \
  --region $AWS_REGION

# Create processed data bucket
aws s3 mb s3://$PROCESSED_DATA_BUCKET \
  --region $AWS_REGION

# Enable versioning (optional)
aws s3api put-bucket-versioning \
  --bucket $RAW_DATA_BUCKET \
  --versioning-configuration Status=Enabled

# Verify buckets
aws s3 ls
```

### Step 5: Create IAM Role for S3 Access

```bash
# Get node role ARN
NODE_ROLE_ARN=$(aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
  --region $AWS_REGION)

# Extract role name
NODE_ROLE_NAME=$(echo $NODE_ROLE_ARN | grep -oP '(?<=instance-profile/)[^/]+')

echo "Node Role: $NODE_ROLE_NAME"

# Create S3 access policy
cat > /tmp/s3-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::yawbdata-raw/*",
        "arn:aws:s3:::yawbdata-raw",
        "arn:aws:s3:::yawbdata-processed/*",
        "arn:aws:s3:::yawbdata-processed"
      ]
    }
  ]
}
EOF

# Attach policy to node role
aws iam put-role-policy \
  --role-name $NODE_ROLE_NAME \
  --policy-name spark-s3-access \
  --policy-document file:///tmp/s3-policy.json

# Verify
aws iam get-role-policy \
  --role-name $NODE_ROLE_NAME \
  --policy-name spark-s3-access
```

### Step 6: Create Kubernetes Namespace

```bash
# Create namespace for Spark jobs
kubectl create namespace default

# Or create custom namespace
kubectl create namespace spark-jobs
```

### Step 7: Create RBAC Configuration

```bash
# Apply Spark RBAC roles
kubectl apply -f infrastructure/kubernetes/rbac/spark-role.yaml
kubectl apply -f infrastructure/kubernetes/rbac/spark-rolebinding.yaml

# Verify
kubectl get roles
kubectl get rolebindings
```

### Step 8: Install Spark Operator

```bash
# Add Helm repository
helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator

# Update repo
helm repo update

# Install Spark Operator
helm install my-spark-operator spark-operator/spark-operator \
  --namespace spark-operator \
  --create-namespace \
  --set webhook.enable=true \
  --set installCRDs=true \
  --wait

# Verify installation
kubectl get pods -n spark-operator
kubectl get crds | grep spark

# Check CRDs available
kubectl api-resources | grep spark
```

### Step 9: Verify Everything Works

```bash
# Check cluster
kubectl cluster-info
kubectl get nodes

# Check namespaces
kubectl get namespaces

# Check Spark Operator
kubectl get pods -n spark-operator

# Check S3 access from node
kubectl run s3-test --image=amazonlinux --rm -it -- \
  sh -c 'aws s3 ls'

# Check job creation capability
kubectl apply -f application/deploy/spark-job.yaml --dry-run=client

echo "✓ Infrastructure setup complete!"
```

---

## Cost Estimation

### Monthly Breakdown (US East 1)

| Service | Instance/Config | Unit Price | Quantity | Monthly |
|---------|-----------------|-----------|----------|---------|
| **EC2** | m5.xlarge | $0.096/hour | 3 nodes | $216/month |
| **EKS** | Control plane | $0.10/hour | 1 cluster | $73/month |
| **S3** | Storage | $0.023/GB | 100 GB | $2.30 |
| **Data Transfer** | Out of region | $0.02/GB | ~4,500 GB | $90/month |
| **Elastic IP** | (if needed) | $0.005/hour | 1 | $3.60 |
| **EBS** | Default volumes | $0.11/GB-month | 150 GB | $16.50 |
| **Load Balancer** | (optional) | $0.0225/hour | 0-1 | $0-16 |
| **—** | **—** | **—** | **TOTAL** | **~$401-417/month** |

### Cost Optimization

```bash
# 1. Scale down nodes when not in use
eksctl scale nodegroup \
  --cluster=$CLUSTER_NAME \
  --name=workers \
  --nodes=1

# 2. Use spot instances (70% cheaper)
eksctl create nodegroup \
  --cluster=$CLUSTER_NAME \
  --spot \
  --name=spot-workers \
  --instance-types=m5.xlarge

# 3. Remove unused resources
# See Cleanup section below
```

---

## Cleanup

### Manual Cleanup

```bash
# ⚠️ WARNING: This is destructive and CANNOT be undone!

# Option 1: Using eksctl (recommended)
source config/env.dev.sh
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION

# Option 2: Using AWS CLI
aws eks delete-cluster --name $CLUSTER_NAME --region $AWS_REGION
aws ec2 delete-security-group --group-id <sg-id>

# Option 3: Using make command
make cleanup
```

### Delete S3 Data

```bash
# Be careful - this deletes all data!

source config/env.dev.sh

# Empty buckets (required before deleting)
aws s3 rm s3://$RAW_DATA_BUCKET --recursive
aws s3 rm s3://$PROCESSED_DATA_BUCKET --recursive

# Delete buckets
aws s3 rb s3://$RAW_DATA_BUCKET
aws s3 rb s3://$PROCESSED_DATA_BUCKET
```

### Delete IAM Roles/Policies

```bash
# Remove S3 access policy from node role
aws iam delete-role-policy \
  --role-name $NODE_ROLE_NAME \
  --policy-name spark-s3-access

# Verify
aws iam list-role-policies --role-name $NODE_ROLE_NAME
```

---

## Troubleshooting

### eksctl Not Found

```bash
# Install eksctl
# macOS
brew install eksctl

# Ubuntu
curl --silent --location \
  "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | \
  tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

### Cluster Creation Fails

```bash
# Check AWS limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A

# Check for existing cluster
eksctl get clusters

# Check CloudFormation stacks
aws cloudformation list-stacks --region $AWS_REGION
```

### kubeconfig Error

```bash
# Reset kubeconfig
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --force

# Or set manually
export KUBECONFIG=~/.kube/config

# Verify
kubectl cluster-info
```

### S3 Access Denied

```bash
# Check node IAM role
NODE_INSTANCE_ID=$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | cut -d'/' -f5)
NODE_ROLE=$(aws ec2 describe-instances \
  --instance-ids $NODE_INSTANCE_ID \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn')

# Check attached policies
aws iam list-role-policies --role-name $NODE_ROLE_NAME

# Verify S3 policy
aws iam get-role-policy \
  --role-name $NODE_ROLE_NAME \
  --policy-name spark-s3-access
```

### Helm Install Fails

```bash
# Update helm repos
helm repo update

# Check chart exists
helm search repo spark-operator

# Install with verbose output
helm install my-spark-operator spark-operator/spark-operator \
  --namespace spark-operator \
  --create-namespace \
  --debug \
  --wait

# Check pod status
kubectl describe pod -n spark-operator
```

### Spark Operator CRD Not Found

```bash
# Verify CRD installed
kubectl get crds | grep spark

# Manually install CRDs
kubectl apply -f \
  https://github.com/GoogleCloudPlatform/spark-on-k8s-operator/raw/master/manifest/crds/sparkoperator.k8s.io_sparkapplications.yaml

# Verify installation
kubectl api-resources | grep SparkApplication
```

---

## Maintenance

### Regular Checks

```bash
# Weekly
kubectl get nodes              # Check node health
kubectl get events            # Check cluster events
aws ec2 describe-instances    # Check instance status

# Monthly
# Review CloudWatch metrics in AWS Console
# Check data transfer costs
# Review unused resources
```

### Upgrades

```bash
# Check EKS version
eksctl get cluster --name=$CLUSTER_NAME

# Upgrade cluster
eksctl upgrade cluster --name=$CLUSTER_NAME

# Upgrade node group
eksctl upgrade nodegroup \
  --cluster=$CLUSTER_NAME \
  --name=workers

# Update Spark Operator
helm upgrade my-spark-operator spark-operator/spark-operator \
  --namespace spark-operator
```

### Monitoring

```bash
# Install CloudWatch Container Insights
eksctl utils associate-iam-oidc-provider \
  --cluster=$CLUSTER_NAME \
  --approve

# View logs in CloudWatch
aws logs tail /aws/eks/$CLUSTER_NAME/cluster --follow
```

---

## Quick Reference

```bash
# List all resources
eksctl get clusters
aws s3 ls
kubectl get all -A

# Get cluster info
eksctl describe cluster --name=$CLUSTER_NAME
aws eks describe-cluster --name=$CLUSTER_NAME

# Connect to node
kubectl debug node/<node-name> -it --image=ubuntu

# Clean up
make cleanup  # or eksctl delete cluster...
```

---

## Next Steps

- Read [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) for application deployment
- See [application/README.md](../application/README.md) for development
- Check [README.md](../README.md) for project overview
