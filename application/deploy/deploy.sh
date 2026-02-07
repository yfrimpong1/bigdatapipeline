#!/bin/bash
set -e # Exit immediately if a command fails

# Load environment configuration
ENVIRONMENT=${1:-dev}
CONFIG_FILE="../../config/env.${ENVIRONMENT}.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    echo "Usage: ./deploy.sh [dev|staging|prod]"
    exit 1
fi

source "$CONFIG_FILE"

TAG=$(git rev-parse --short HEAD)

if ! helm list -n spark-operator | grep -q "my-spark-operator"; then
    echo "Installing Spark Operator..."
    helm install my-spark-operator spark-operator/spark-operator \
        --namespace spark-operator \
        --create-namespace \
        --set webhook.enable=true \
        --set installCRDs=true \
        --wait
else
    echo "Spark Operator is already installed."
fi


echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION \
| docker login --username AWS \
--password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "Building Docker image..."
docker build -t $IMAGE_NAME:$TAG ../../application/docker/

echo "Tagging image..."
docker tag $IMAGE_NAME:$TAG $IMAGE_URI

echo "Pushing image to ECR..."
docker push ${IMAGE_URI}

echo "Deploying Spark job to EKS..."
kubectl apply -f spark-job.yaml

echo "Deployment Successful!"
