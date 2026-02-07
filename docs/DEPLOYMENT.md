# Deployment Guide

Complete guide for deploying the BigData Pipeline to EKS using manual or automated (Jenkins) approaches.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Manual Deployment](#manual-deployment)
3. [Automated Deployment (Jenkins)](#automated-deployment-jenkins)
4. [Comparison](#comparison)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Local Machine Requirements

```bash
# Required tools
aws --version           # AWS CLI v2
docker --version        # Docker CLI
kubectl version --client # kubectl 1.20+
helm version            # Helm 3+
spark-submit --version  # Spark 3.3+ (for local testing)

# AWS Credentials configured
aws configure

# EKS cluster already created (or use infrastructure/README.md to setup)
kubectl cluster-info
```

### Jenkins Requirements (for automated deployment)

- Jenkins 2.350+
- Docker engine accessible to Jenkins
- AWS credentials configured in Jenkins
- GitHub webhook capability
- Git plugin installed

---

## Manual Deployment

### Step 1: Source Environment Configuration

```bash
cd /Users/yfrimpong/DevOps/BigDataPipeline

# Load environment variables for your target environment
source config/env.dev.sh     # or env.staging.sh, env.prod.sh

# Verify environment is loaded
echo $AWS_REGION
echo $CLUSTER_NAME
echo $IMAGE_NAME
```

### Step 2: Verify Prerequisites

```bash
# Check AWS access
aws sts get-caller-identity

# Check EKS cluster access
kubectl cluster-info

# Check Spark Operator installed
kubectl get pods -n spark-operator || \
  echo "Spark Operator not installed. Run: make setup"

# Check ECR repository exists
aws ecr describe-repositories --repository-names $IMAGE_NAME
```

### Step 3: Build Docker Image

```bash
# Navigate to project root
cd /Users/yfrimpong/DevOps/BigDataPipeline

# Build image with git commit tag
docker build -f application/docker/Dockerfile \
  -t $IMAGE_NAME:latest \
  .

# Verify image built
docker images | grep $IMAGE_NAME
```

### Step 4: Authenticate with ECR

```bash
# Get ECR login token (valid for 12 hours)
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Verify login (should not print "Login Succeeded")
docker ps  # If this works, Docker auth is ok
```

### Step 5: Tag and Push Image

```bash
# Tag image for ECR
docker tag $IMAGE_NAME:latest $ECR_REPO:latest

# Push to ECR
docker push $ECR_REPO:latest

# Verify in ECR
aws ecr list-images --repository-name $IMAGE_NAME
```

### Step 6: Update Kubernetes Manifest

```bash
# Update spark-job.yaml with correct image URI
sed -i "s|image:.*|image: $IMAGE_URI|g" application/deploy/spark-job.yaml

# Verify update
grep "image:" application/deploy/spark-job.yaml
```

### Step 7: Deploy to Kubernetes

```bash
# Apply manifest
kubectl apply -f application/deploy/spark-job.yaml

# Verify job created
kubectl get sparkapplications
```

### Step 8: Monitor Deployment

```bash
# Check job status
kubectl get sparkapplications bigdata-job

# Watch status until SUCCEEDED or FAILED
kubectl describe sparkapplication bigdata-job

# Check pods
kubectl get pods -l spark-app-selector=bigdata-job

# View driver logs
POD=$(kubectl get pods -l spark-role=driver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f $POD
```

### Step 9: Verify Results

```bash
# Check S3 output
aws s3 ls s3://$PROCESSED_DATA_BUCKET/output/

# List processed data
aws s3 ls s3://$PROCESSED_DATA_BUCKET/output/ --recursive

# Download sample output
aws s3 cp s3://$PROCESSED_DATA_BUCKET/output/part-00000-*.parquet . --recursive
```

### Step 10: Cleanup (Optional)

```bash
# Delete completed job
kubectl delete sparkapplication bigdata-job

# Or wait for it to auto-cleanup after completion
```

---

## Automated Deployment (Jenkins)

### Prerequisites

1. Jenkins server running
2. GitHub repository connected
3. AWS credentials configured in Jenkins
4. Docker socket mounted to Jenkins container

### Option A: Create Jenkins Job from GUI

#### 1. Create Multibranch Pipeline Job

```
Jenkins > New Item
  - Name: bigdata-app-deploy
  - Type: Multibranch Pipeline
  - Save
```

#### 2. Configure Branch Sources

```
Configuration > Branch Sources:
  - GitHub
    - Repository HTTPS URL: https://github.com/yfrimpong1/bigdatapipeline.git
    - Credentials: [Add GitHub credentials]
    - Behaviors: Discover branches
```

#### 3. Set Script Path

```
Configuration > Build Configuration:
  - Script path: .jenkins/Jenkinsfile
```

#### 4. Save Configuration

Jenkins now automatically discovers and builds the `main` branch.

#### 5. Configure GitHub Webhook

```
GitHub Repository Settings:
  - Webhooks > Add webhook
    - Payload URL: https://your-jenkins-server/github-webhook/
    - Content type: application/json
    - Events: Push events
    - Active: ✓
```

### Option B: Create Jenkins Job from Pipeline Script

```groovy
// Create via Jenkins script console
pipelineJob('bigdata-app-deploy') {
  definition {
    cps {
      script("""
        pipeline {
          agent any
          triggers {
            githubPush()
          }
          stages {
            stage('Deploy') {
              steps {
                checkout scm
                sh '''
                  source config/env.dev.sh
                  chmod +x application/deploy/deploy.sh
                  ./application/deploy/deploy.sh dev
                '''
              }
            }
          }
        }
      """.stripIndent())
      sandbox(true)
    }
  }
}
```

### Option C: Trigger Deployment (Jenkins CLI)

```bash
# If using Jenkins CLI
java -jar jenkins-cli.jar -s http://jenkins-server \
  build bigdata-app-deploy -p ENVIRONMENT=dev

# Or via curl
curl -X POST http://jenkins-server/job/bigdata-app-deploy/buildWithParameters \
  -u user:token \
  -F ENVIRONMENT=dev
```

### Triggering Deployment

#### Automatic (on push)

```bash
# Just push code - Jenkins automatically deploys
git add application/src/job.py
git commit -m "Update Spark job logic"
git push origin main

# Jenkins automatically:
# 1. Triggers Multibranch Pipeline
# 2. Checks out code
# 3. Runs .jenkins/Jenkinsfile
# 4. Builds Docker image
# 5. Pushes to ECR
# 6. Deploys to EKS
```

#### Manual (on demand)

```
Jenkins Web UI:
  1. Navigate to: Jenkins > bigdata-app-deploy > main
  2. Click: Build Now
  3. Monitor: Build #123 (in progress)
```

### Monitoring Jenkins Deployment

```bash
# View console output
# Jenkins > bigdata-app-deploy > main > Build #123 > Console Output

# Real-time logs (on Jenkins server)
tail -f /var/jenkins_home/jobs/bigdata-app-deploy/builds/123/log

# Or via Jenkins API
curl -s http://jenkins-server/job/bigdata-app-deploy/123/consoleText
```

### Infrastructure Setup via Jenkins

Create separate manual-approval infrastructure job:

```bash
# Create job for infrastructure
Jenkins > New Item
  - Name: bigdata-infra-setup
  - Type: Pipeline
  - Script path: .jenkins/Jenkinsfile.infra
```

Trigger manually:

```
Jenkins > bigdata-infra-setup > Build with Parameters > Build
```

---

## Comparison

| Aspect | Manual | Jenkins |
|--------|--------|---------|
| **Trigger** | Developer command | Code push or manual click |
| **Speed** | ~10-15 minutes | ~10-15 minutes |
| **Debugging** | Full control, step-by-step | Logs in Jenkins UI |
| **Audit Trail** | Git history | Jenkins build history |
| **Scalability** | Limited | Unlimited (parallel builds) |
| **Consistency** | Depends on user | Always consistent |
| **Learning Curve** | Steeper | Easier (familiar interface) |
| **Best For** | Development/testing | Production deployments |

---

## Troubleshooting

### Docker Build Fails

```bash
# Check syntax
docker build -f application/docker/Dockerfile --dry-run .

# Check for missing files
ls -la application/docker/
ls -la application/src/

# Build with verbose output
docker build -f application/docker/Dockerfile --progress=plain .
```

### ECR Push Fails

```bash
# Re-authenticate
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Check ECR repository exists
aws ecr describe-repositories --repository-names $IMAGE_NAME

# Create repository if missing
aws ecr create-repository --repository-name $IMAGE_NAME --region $AWS_REGION
```

### Kubernetes Deployment Fails

```bash
# Check manifest syntax
kubectl apply -f application/deploy/spark-job.yaml --dry-run=client

# Check cluster access
kubectl cluster-info
kubectl get nodes

# Check Spark Operator installed
kubectl get pods -n spark-operator

# If missing, install:
helm install my-spark-operator spark-operator/spark-operator \
  --namespace spark-operator --create-namespace
```

### Pod Fails with ImagePullBackOff

```bash
# Verify image exists in ECR
aws ecr describe-images --repository-name $IMAGE_NAME

# Check image URI in manifest
grep "image:" application/deploy/spark-job.yaml

# Check image pull secrets
kubectl get secrets -n default

# Verify node can pull image
kubectl exec -it <pod-name> -- docker images
```

### Job Timeout or OOM

```bash
# Check resource limits in manifest
kubectl describe sparkapplication bigdata-job

# Increase in application/deploy/spark-job.yaml
spec:
  driver:
    memory: 8g    # Increase from 2g

# Or update env config
export SPARK_DRIVER_MEMORY=8g

# Redeploy
kubectl apply -f application/deploy/spark-job.yaml
```

### Jenkins Build Fails

**Check logs:**
```bash
# In Jenkins UI: Job > Build > Console Output

# Or via SSH to Jenkins server
tail -f /var/jenkins_home/jobs/bigdata-app-deploy/builds/lastBuild/log
```

**Common issues:**

```bash
# 1. Docker daemon not available
# Solution: Ensure Docker socket mounted to Jenkins

# 2. AWS credentials not found
# Solution: Configure AWS credentials in Jenkins > Manage Jenkins > Credentials

# 3. Git checkout fails
# Solution: Add GitHub SSH key to Jenkins credentials

# 4. kubectl not found
# Solution: Install kubectl in Jenkins container or use kubeconfig
```

---

## Quick Reference

### Using Makefile (Recommended)

```bash
# Deploy with one command
make deploy ENVIRONMENT=dev

# Build and push
make docker-push ENVIRONMENT=staging

# Monitor
make status
make logs-driver

# Test locally
make local-run ENVIRONMENT=dev
```

### Using Manual Commands

```bash
# Source config
source config/env.dev.sh

# Deploy
bash application/deploy/deploy.sh dev

# Monitor
kubectl get sparkapplications
kubectl logs -f <driver-pod>
```

### Using Jenkins

```bash
# Push code (triggers automatic deployment)
git push origin main

# Or trigger manually
jenkins-cli build bigdata-app-deploy
```

---

## Next Steps

- Check [infrastructure/README.md](../infrastructure/README.md) for EKS setup
- See [application/README.md](../application/README.md) for development
- Review [README.md](../README.md) for project overview
