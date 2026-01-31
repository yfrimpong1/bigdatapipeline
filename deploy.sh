#!/bin/bash
set -e # Exit immediately if a command fails

#Variables
AWS_REGION="us-east-1"
ACCOUNT_ID="336107977801"
IMAGE_NAME="bigdata-job"
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}:latest"
// 336107977801.dkr.ecr.us-east-1.amazonaws.com/bigdata-job:latest

TAG=$(git rev-parse --short HEAD)

echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION \
| docker login --username AWS \
--password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "Building Docker image..."
docker build -t $IMAGE_NAME:$TAG .

echo "Tagging image..."
docker tag $IMAGE_NAME:$TAG $IMAGE_URI

echo "Pushing image to ECR..."
docker push ${IMAGE_URI}

echo "Deploying Spark job to EKS..."
kubectl apply -f spark-job.yaml

echo "Deployment Successful!"
