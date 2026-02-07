#!/bin/bash
# Development Environment Configuration

export AWS_REGION="us-east-1"
export AWS_ACCOUNT_ID="336107977801"
export ENVIRONMENT="dev"
export CLUSTER_NAME="bigdata-dev"
export IMAGE_NAME="bigdata-job"
export ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}"
export IMAGE_URI="${ECR_REPO}:latest"

# S3 Buckets
export RAW_DATA_BUCKET="yawbdata-raw"
export PROCESSED_DATA_BUCKET="yawbdata-processed"

# Resource settings for dev (minimal)
export SPARK_DRIVER_CORES="1"
export SPARK_DRIVER_MEMORY="2g"
export SPARK_EXECUTOR_CORES="2"
export SPARK_EXECUTOR_INSTANCES="2"
export SPARK_EXECUTOR_MEMORY="2g"
