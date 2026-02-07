#!/bin/bash

# --- SECURITY SETUP ---
# Ensure .gitignore exists and tracks .pem files to prevent accidental leaks
if [ ! -f .gitignore ]; then
    touch .gitignore
fi

if ! grep -q "*.pem" .gitignore; then
    echo "*.pem" >> .gitignore
    echo "Added *.pem to .gitignore for security."
fi

# --- KEYPAIR SETUP ---
KEY_NAME="eks-key"
KEY_FILE="${KEY_NAME}.pem"

if [ ! -f "$KEY_FILE" ]; then
    echo "Generating new AWS Key Pair: $KEY_NAME..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_FILE"
    chmod 400 "$KEY_FILE"
else
    echo "Using existing local key: $KEY_FILE"
fi

# --- CLUSTER CREATION ---
eksctl create cluster \
  --name bigdata-eks \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type m5.xlarge \
  --nodes 3 \
  --managed \
  --ssh-access \
  --ssh-public-key "$KEY_NAME"

# --S3 BUCKET CREATION & UPLOAD--
aws s3 mb s3://yawbdata-raw --region us-east-1
aws s3api put-object --bucket yawbdata-raw --key input/

# Upload the CSV file
echo "Uploading countries.csv to S3..."
aws s3 cp countries.csv s3://yawbdata-raw/input/

aws s3 mb s3://yawbdata-processed --region us-east-1
aws s3api put-object --bucket yawbdata-processed --key output/

