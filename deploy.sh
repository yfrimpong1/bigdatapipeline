#!/bin/bash
set -e

AWS_REGION=us-east-1
ACCOUNT_ID=336107977801
IMAGE_NAME=bigdata-job
TAG=$(git rev-parse --short HEAD)

echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION \
| docker login --username AWS \
--password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "Building Docker image..."
docker build -t $IMAGE_NAME:$TAG .

echo "Tagging image..."
docker tag $IMAGE_NAME:$TAG \
$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_NAME:latest

echo "Pushing image to ECR..."
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_NAME:latest

echo "Deploying Spark job to EKS..."
kubectl apply -f spark-job.yaml
