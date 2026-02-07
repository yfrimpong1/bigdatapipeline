#!/bin/bash

# 1. Delete the EKS Cluster and all associated resources
# This removes the control plane and the node groups
echo "Deleting EKS cluster: bigdata-eks..."
eksctl delete cluster --name bigdata-eks --region us-east-1

# 2. Force delete S3 buckets (removes all objects and the bucket itself)
echo "Cleaning up S3 buckets..."

aws s3 rb s3://yawbdata-raw-bucket --force
aws s3 rb s3://yawbdata-processed-bucket --force

echo "Cleanup complete."

