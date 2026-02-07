# Manual Build & Deployment Guide

Complete step-by-step instructions for building and deploying the BigData Pipeline without using Jenkins.

## Manual Build Steps

### 1. Navigate to project root
```bash
cd /Users/yfrimpong/DevOps/BigDataPipeline
```

### 2. Load environment configuration
Choose your environment: `dev`, `staging`, or `prod`

```bash
source config/env.dev.sh
```

Or for other environments:
```bash
source config/env.staging.sh    # Staging environment
source config/env.prod.sh       # Production environment
```

### 3. Verify environment variables are set
```bash
echo "AWS_REGION: $AWS_REGION"
echo "AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "IMAGE_NAME: $IMAGE_NAME"
echo "ECR_REPO: $ECR_REPO"
```

### 4. Build Docker image
The Dockerfile automatically downloads S3 connector jars from Maven Central.

```bash
docker build -f application/docker/Dockerfile -t $IMAGE_NAME:latest .
```

**Expected output:**
```
Sending build context to Docker daemon  XX.XX MB
Step 1/X : FROM apache/spark-py:latest
...
Successfully built abc123def456
Successfully tagged bigdata-job:latest
```

### 5. Verify image was built
```bash
docker images | grep $IMAGE_NAME
```

### 6. Login to ECR
```bash
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

**Expected output:**
```
Login Succeeded
```

### 7. Tag image for ECR
```bash
docker tag $IMAGE_NAME:latest $ECR_REPO:latest
```

### 8. Push to ECR
```bash
docker push $ECR_REPO:latest
```

**Expected output:**
```
The push refers to repository [336107977801.dkr.ecr.us-east-1.amazonaws.com/bigdata-job]
abc123: Pushed
latest: digest: sha256:abc123... size: 1234
```

### 9. Verify image in ECR
```bash
aws ecr list-images --repository-name $IMAGE_NAME
```

---

## Manual Deployment to EKS

### 1. Verify Spark Operator is installed
```bash
kubectl get pods -n spark-operator
```

**Expected output:**
```
NAME                                                 READY   STATUS
spark-operator-spark-operator-xxx-yyy               1/1     Running
```

### 2. (If not installed) Install Spark Operator
If Spark Operator is not installed, run these commands:

```bash
# Add Helm repository
helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator
helm repo update

# Install Spark Operator
helm install my-spark-operator spark-operator/spark-operator \
  --namespace spark-operator \
  --create-namespace \
  --set webhook.enable=true \
  --set installCRDs=true \
  --wait
```

### 3. Verify EKS cluster access
```bash
kubectl cluster-info
kubectl get nodes
```

**Expected output:**
```
NAME                          STATUS   ROLES    AGE
ip-172-31-xxx-xxx.ec2.internal   Ready    <none>   XX days
ip-172-31-yyy-yyy.ec2.internal   Ready    <none>   XX days
ip-172-31-zzz-zzz.ec2.internal   Ready    <none>   XX days
```

### 4. Deploy Spark job
```bash
kubectl apply -f application/deploy/spark-job.yaml
```

**Expected output:**
```
sparkapplication.sparkoperator.k8s.io/bigdata-job created
```

### 5. Monitor deployment
Check job status:
```bash
kubectl get sparkapplications
```

Get detailed information:
```bash
kubectl describe sparkapplication bigdata-job
```

### 6. View driver logs
Stream real-time logs from the driver pod:
```bash
kubectl logs -f bigdata-job-driver
```

Or view executor logs:
```bash
kubectl logs -f bigdata-job-exec-1
```

### 7. Check output in S3
Once the job completes, verify results:
```bash
aws s3 ls s3://yawbdata-processed/output/
```

List all output files:
```bash
aws s3 ls s3://yawbdata-processed/output/ --recursive
```

---

## Complete Build & Deploy Example (Dev Environment)

```bash
# 1. Setup
cd /Users/yfrimpong/DevOps/BigDataPipeline
source config/env.dev.sh

# 2. Build
docker build -f application/docker/Dockerfile -t $IMAGE_NAME:latest .

# 3. Push to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker tag $IMAGE_NAME:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

# 4. Deploy
kubectl apply -f application/deploy/spark-job.yaml

# 5. Monitor
kubectl logs -f bigdata-job-driver
```

---

## Troubleshooting

### Docker build fails with "file not found"
**Problem:** `Error: COPY src/job.py: file not found`

**Solution:** Make sure you're in the project root directory:
```bash
pwd  # Should output: /Users/yfrimpong/DevOps/BigDataPipeline
```

### ECR login fails
**Problem:** `no basic auth credentials`

**Solution:** Verify AWS credentials are configured:
```bash
aws sts get-caller-identity
aws configure  # Reconfigure if needed
```

### Jar download fails in Docker build
**Problem:** `curl: (7) Failed to connect to repo1.maven.org port 443`

**Solution:** Check internet connectivity or use a corporate proxy:
```bash
docker build --build-arg HTTP_PROXY=http://proxy:port ...
```

### Pod stuck in ImagePullBackOff
**Problem:** `Failed to pull image`

**Solution:** Verify image exists in ECR:
```bash
aws ecr describe-images --repository-name $IMAGE_NAME
```

And check that the image URI in `application/deploy/spark-job.yaml` matches:
```bash
grep "image:" application/deploy/spark-job.yaml
```

### Job fails with S3 access error
**Problem:** `Failed to locate S3 credentials`

**Solution:** Verify IAM role has S3 permissions:
```bash
# Check node role
kubectl exec -it bigdata-job-driver -- \
  aws s3 ls s3://yawbdata-raw/
```

### No pods created
**Problem:** `kubectl get pods` shows nothing

**Solution:** Check if Spark Operator namespace is different:
```bash
kubectl get sparkapplications -A
kubectl get pods -n spark-operator
```

---

## Environment Configurations

### Development (dev)
```bash
source config/env.dev.sh
# 1 driver core, 2 executor cores, 2 executors
# Best for: Testing, debugging
```

### Staging (staging)
```bash
source config/env.staging.sh
# 2 driver cores, 2 executor cores, 3 executors
# Best for: Pre-production testing
```

### Production (prod)
```bash
source config/env.prod.sh
# 4 driver cores, 4 executor cores, 5 executors
# Best for: Full-scale data processing
```

---

## Useful Commands

### Check job status
```bash
kubectl get sparkapplications
kubectl get sparkapplications -o wide
kubectl describe sparkapplication bigdata-job
```

### View logs
```bash
# Driver logs
kubectl logs bigdata-job-driver

# Executor logs
kubectl logs bigdata-job-exec-1

# Follow logs in real-time
kubectl logs -f bigdata-job-driver
```

### Check resources
```bash
# Pod resources
kubectl get pods -o wide

# Node resources
kubectl top nodes
kubectl top pods
```

### Delete job
```bash
kubectl delete sparkapplication bigdata-job
```

### Check S3 data
```bash
# List input bucket
aws s3 ls s3://yawbdata-raw/input/

# List output bucket
aws s3 ls s3://yawbdata-processed/output/

# Download a file
aws s3 cp s3://yawbdata-processed/output/part-00000.parquet .
```

---

## Using Makefile (Shorthand)

While the above steps show manual execution, you can also use the Makefile for convenience:

```bash
# Build and push
make docker-push ENVIRONMENT=dev

# Deploy
make deploy ENVIRONMENT=dev

# Monitor
make status
make logs-driver
make logs-all

# Run locally
make local-run ENVIRONMENT=dev

# Test
make test

# Help
make help
```

---

## Next Steps

1. **Verify Prerequisites**: Ensure AWS CLI, Docker, kubectl, and helm are installed
2. **Configure AWS**: Run `aws configure` and test with `aws sts get-caller-identity`
3. **Verify EKS Access**: Run `kubectl cluster-info` and `kubectl get nodes`
4. **Build**: Follow the build steps above
5. **Deploy**: Follow the deployment steps above
6. **Monitor**: Check logs and S3 output

For more details, see:
- [README.md](../README.md) - Project overview
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment guide (manual + Jenkins)
- [infrastructure/README.md](../infrastructure/README.md) - Infrastructure setup
- [application/README.md](../application/README.md) - Application development
