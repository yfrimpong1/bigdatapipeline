# Cost Optimization & Cleanup Guide

## Overview
This guide helps you manage AWS infrastructure costs and understand cleanup procedures.

## Monthly Cost Breakdown (Current)

| Component | Monthly Cost | Notes |
|-----------|-------------|-------|
| EKS Control Plane | $73 | Unavoidable for managed Kubernetes |
| EC2 Nodes (3x m5.xlarge) | $200-300 | Largest cost; can be optimized |
| EBS Volumes | $15-30 | Storage for EBS-backed volumes |
| S3 Storage | $2-50 | Depends on data size (1KB-100GB) |
| Data Transfer | $0-90 | Outbound transfer costs |
| **Total Monthly** | **$290-543** | Range based on usage |

## Cost Optimization Strategies

### 1. Scale Down (Temporary Pause) - Saves 70-80%
Best for: Development/Testing environments, Overnight/Weekend pauses

```bash
# Scale down Spark executors instead of deleting cluster
kubectl scale sparkapp spark-job --replicas=0 -n spark

# Or scale down EC2 nodes
aws autoscaling set-desired-capacity --auto-scaling-group-name \
    eksctl-bigdata-eks-nodegroup-ng-* --desired-capacity 1 --region us-east-1
```

**Cost Impact:**
- Keeps EKS control plane: $73/month
- Scales nodes to 1: ~$70/month
- **Monthly savings: $150-200**

### 2. Use Spot Instances - Saves 60-70%
Best for: Non-critical jobs, Batch processing, Dev/Staging

**Requires 1 Makefile change:**
```makefile
# In Makefile, add spot instance configuration
eksctl create nodegroup \
    --cluster=bigdata-eks \
    --name=spot-ng \
    --instance-types=m5.xlarge \
    --spot \
    --desired-capacity=3
```

**Cost Impact:**
- Spot instances cost ~$0.10/hour vs $0.192/hour on-demand
- **Monthly savings: $50-150 (depending on interruption tolerance)**

**Limitations:**
- Instances can be terminated anytime
- Not suitable for long-running jobs
- Good for batch processing and experiments

### 3. Schedule-Based Shutdown - Saves 100%
Best for: Development environments, Business hours only

**Lambda + EventBridge automation:**
```bash
# Create Lambda function to cleanup cluster on schedule
# Delete cluster at 6 PM every Friday
# Recreate cluster Monday 8 AM via Jenkins

# Cost during off-hours: $0
# Setup time: 2-3 hours
# Maintenance: Low
```

### 4. Full Cleanup (Recommended for unused projects)
Best for: When you won't use cluster for weeks/months

```bash
make cleanup ENVIRONMENT=dev
```

**Cost Impact:**
- All AWS resources deleted
- **Monthly savings: $290-543 (100%)**
- Data is NOT recoverable
- Rebuild time: 10-15 minutes with `make setup`

## Quick Cleanup Commands

### Delete Everything (Most Cost Savings)
```bash
# Production safety check
./infrastructure/scripts/cleanup.sh prod

# Ask for confirmation, then deletes all resources
# Saves: ~$400-500/month in production
# Redeploy with: make setup ENVIRONMENT=prod
```

### Scale Down (Temporary Pause)
```bash
# Stop just the Spark job
kubectl delete sparkapp spark-job -n spark

# Start it again later
kubectl apply -f application/deploy/spark-job.yaml
```

### Reduce Node Count (Partial Cleanup)
```bash
# Keep cluster but reduce nodes from 3 to 1
aws autoscaling set-desired-capacity \
    --auto-scaling-group-name $(aws autoscaling describe-auto-scaling-groups \
        --query "AutoScalingGroups[0].AutoScalingGroupName" \
        --output text) \
    --desired-capacity 1 \
    --region us-east-1

# Cost: $73 (EKS) + $70 (1 node) = $143/month
# Savings: ~$200/month
```

## Cost Monitoring

### Check Current Resource Usage
```bash
# Storage usage
aws s3 ls s3://yawbdata-raw-bucket --recursive --summarize

# EC2 usage
aws ec2 describe-instances --region us-east-1 \
    --query 'Reservations[*].Instances[*].{Type:InstanceType, State:State.Name}' \
    --output table

# EKS node usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n spark
```

### Set AWS Cost Alerts
```bash
# Use AWS Budgets to alert when spending exceeds threshold
# 1. Go to AWS Budgets console
# 2. Create budget: $100/month for dev environment
# 3. Add alert when spending exceeds 50%
```

## Cleanup Script Details

The enhanced `infrastructure/scripts/cleanup.sh` performs these steps:

1. **EKS Cluster Deletion** - Removes managed Kubernetes cluster
2. **Security Group Cleanup** - Deletes cluster-associated security groups
3. **Elastic IP Release** - Frees up EIPs to avoid charges
4. **S3 Bucket Deletion** - Empties and removes data buckets
5. **IAM Role Cleanup** - Removes cluster-associated IAM roles
6. **CloudFormation Stack Cleanup** - Removes any remaining stacks

**Safety Features:**
- Environment variable support (dev/staging/prod)
- User confirmation required
- Non-blocking error handling (continues even if step fails)
- Clear status messages

## Cost Optimization Decision Tree

```
Is the cluster actively used?
├─ YES, daily jobs
│  └─ Use current setup (~$400/month)
│     OR use Spot instances (~$250/month)
│
├─ NO, occasional jobs
│  └─ Scale to 1 node (~$150/month)
│     OR delete cluster (~$0/month)
│
└─ NO, won't use for weeks
   └─ RUN CLEANUP SCRIPT (~$0/month)
      Redeploy anytime with: make setup
```

## Disaster Recovery

### If You Accidentally Ran Cleanup

Don't panic! Infrastructure is reproducible:

```bash
# Redeploy everything
make setup ENVIRONMENT=prod

# Recreate data processing pipeline
make deploy ENVIRONMENT=prod

# Check status
make status
```

**Time to recovery:** ~10-15 minutes
**Data recovery:** Data in S3 is lost unless you have backups

## Recommended Environment-Specific Strategy

### Development
- **Default:** Scale to 1 node (save ~$200/month)
- **During active work:** 3 nodes
- **Nightly:** Scale to 0 nodes
- **Monthly cost:** $100-200

### Staging
- **Default:** 2 nodes (keep one running)
- **During testing:** 3 nodes
- **During production incidents:** 5 nodes
- **Monthly cost:** $150-300

### Production
- **Always:** 3+ nodes (high availability)
- **Peak load:** 5-10 nodes (auto-scaling)
- **Off-hours:** 3 nodes minimum
- **Monthly cost:** $300-500

## FAQ

**Q: Can I recover deleted data?**
A: No, cleanup deletes S3 buckets. Make backups before cleanup.

**Q: How long to redeploy?**
A: ~10-15 minutes with `make setup`

**Q: What happens to ongoing jobs?**
A: Running jobs are terminated. Use `kubectl delete` to gracefully stop them first.

**Q: Can I partially clean up?**
A: Yes, manually delete specific resources:
   - Jobs: `kubectl delete sparkapp spark-job`
   - Nodes: `aws autoscaling set-desired-capacity`
   - S3: `aws s3 rm --recursive s3://bucket`

**Q: Best practice for CI/CD?**
A: Keep dev/staging auto-cleanup nightly, production manual-approval only.

## Next Steps

1. **Review cleanup script:** `cat infrastructure/scripts/cleanup.sh`
2. **For dev environment:** Run cleanup after working sessions
3. **For production:** Set up scheduled scaling or use spot instances
4. **Monitor costs:** Check AWS Billing dashboard weekly
5. **Plan capacity:** Use cost tools to forecast multi-month spend

---

**Last Updated:** 2024
**Maintainer:** DevOps Team
