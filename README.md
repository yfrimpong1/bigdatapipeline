# BigData Pipeline

A production-ready Apache Spark data processing pipeline deployed on Amazon EKS with CI/CD automation via Jenkins. This project demonstrates containerized big data workflows with S3 integration for scalable data processing.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Development](#development)
- [Deployment](#deployment)
- [Contributing](#contributing)

## 🎯 Overview

This project implements an automated big data processing pipeline that:

- **Processes data** using Apache Spark running on Kubernetes
- **Reads** raw data from S3 (`s3a://yawbdata-raw/input/`)
- **Transforms** data with PySpark (grouping by country, aggregation)
- **Writes** processed results to S3 (`s3a://yawbdata-processed/output/`)
- **Automates** the entire workflow with Jenkins CI/CD
- **Scales** horizontally with Kubernetes and Spark Operator

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Jenkins Pipeline                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Checkout   │→ │ Build Image  │→ │  Deploy to EKS  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Amazon ECR (Container Registry)                │
│              bigdata-job:latest                             │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           Amazon EKS (Kubernetes Cluster)                   │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │  Spark Driver  │→ │   Executor 1   │  │   Executor 2   │ │
│  │   (1 core)     │  │  (2 cores ea)  │  │  (2 cores ea)  │ │
│  └────────────────┘  └────────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────────┘
         │                       │                      │
         └───────────────────────┼──────────────────────┘
                                 ▼
                    ┌────────────────────────┐
                    │   Amazon S3 Buckets    │
                    │  ┌──────────────────┐  │
                    │  │ yawbdata-raw     │  │ (Input)
                    │  │ yawbdata-processed│  │ (Output)
                    │  └──────────────────┘  │
                    └────────────────────────┘
```

## 📁 Project Structure

```
BigDataPipeline/
├── application/                    # Spark application code
│   ├── src/
│   │   └── job.py                 # Main Spark job
│   ├── docker/
│   │   └── Dockerfile             # Container definition
│   ├── deploy/
│   │   ├── deploy.sh              # Deployment script
│   │   └── spark-job.yaml         # K8s manifest
│   ├── tests/
│   │   ├── test_job.py            # Unit tests
│   │   └── conftest.py            # pytest config
│   ├── requirements.txt           # Python dependencies
│   └── README.md                  # Developer guide
│
├── infrastructure/                # Infrastructure as Code
│   ├── scripts/
│   │   ├── setup.sh               # EKS cluster setup
│   │   └── cleanup.sh             # Resource cleanup
│   ├── kubernetes/
│   │   └── rbac/
│   │       ├── spark-role.yaml
│   │       └── spark-rolebinding.yaml
│   ├── aws/
│   │   └── iam-policy.json        # S3 access policy
│   └── README.md                  # Infrastructure guide
│
├── config/                        # Environment configurations
│   ├── env.dev.sh                # Dev environment
│   ├── env.staging.sh            # Staging environment
│   └── env.prod.sh               # Production environment
│
├── data/                          # Data files
│   ├── countries.csv
│   ├── yawbdata-raw.json
│   └── yawbdata-processed.json
│
├── libs/                          # External dependencies
│   ├── aws-java-sdk-bundle-1.12.262.jar
│   └── hadoop-aws-3.3.4.jar
│
├── docs/                          # Documentation
│   └── DEPLOYMENT.md             # Deployment guide
│
├── .jenkins/                      # Jenkins pipeline definitions
│   ├── Jenkinsfile               # App deployment (auto-trigger)
│   └── Jenkinsfile.infra         # Infra setup (manual)
│
├── .github/                       # GitHub actions (if used)
├── Makefile                       # Build automation
├── README.md                      # This file
├── .gitignore                    # Git ignore rules
└── .git/                         # Git repository
```

## 🚀 Quick Start

### Prerequisites

```bash
# Install required tools
brew install awscli eksctl helm kubectl docker  # macOS
# Or: apt-get install awscli eksctl helm kubectl docker-ce  # Ubuntu

# Verify installation
aws --version && eksctl version && helm version && kubectl version --client
```

### 1. Setup Infrastructure (One-time)

```bash
cd /Users/yfrimpong/DevOps/BigDataPipeline

# Load environment
source config/env.dev.sh

# Create EKS cluster (takes ~20 minutes)
make setup
```

### 2. Deploy Application

```bash
# Build and push Docker image
make docker-push ENVIRONMENT=dev

# Deploy to EKS
make deploy ENVIRONMENT=dev

# Monitor
make status
make logs-driver
```

### 3. Verify Results

```bash
# Check S3 output
aws s3 ls s3://yawbdata-processed/output/

# Or use CLI
kubectl get sparkapplications
kubectl logs -f bigdata-job-driver
```

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [application/README.md](application/README.md) | Developer guide - how to develop and test the Spark job |
| [infrastructure/README.md](infrastructure/README.md) | Infrastructure setup - how to create EKS cluster and S3 buckets |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Deployment guide - manual and Jenkins automation options |

## 💻 Development

### Local Development

```bash
# Install dependencies
pip install -r application/requirements.txt

# Run locally
make local-run ENVIRONMENT=dev

# Test
make test

# Modify job.py and commit
vim application/src/job.py
git add application/src/job.py
git commit -m "feature: add new transformation"
git push origin main  # Jenkins automatically deploys!
```

### Development Tools

```bash
# Code validation
make validate

# Run tests with coverage
python -m pytest application/tests/ --cov=application/src

# Format code
black application/src/job.py

# Lint
flake8 application/src/job.py
```

## 🔧 Deployment

### Using Makefile (Recommended)

```bash
# Deploy with single command
make deploy ENVIRONMENT=dev

# Or step-by-step
make docker-build ENVIRONMENT=dev
make docker-push ENVIRONMENT=dev
make deploy ENVIRONMENT=dev
```

### Using Jenkins (Automated)

```bash
# Just push your code!
git push origin main

# Jenkins automatically:
# 1. Builds Docker image
# 2. Pushes to ECR
# 3. Deploys to EKS
# 4. Monitors deployment
```

### Using Manual Commands

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for 10-step manual process.

## 📊 Monitoring

```bash
# Check job status
make status

# View driver logs
make logs-driver

# View all logs
make logs-all

# Or manually
kubectl get sparkapplications
kubectl logs -f bigdata-job-driver
```

## 🧹 Cleanup

```bash
# Delete all AWS resources (⚠️ Cannot be undone)
make cleanup

# Or selectively
kubectl delete sparkapplication bigdata-job
aws s3 rm s3://yawbdata-processed --recursive
```

## 📋 Makefile Commands

```bash
make help              # Show all commands

# Infrastructure
make setup            # Create EKS cluster
make cleanup          # Delete all resources

# Building
make validate         # Check syntax
make docker-build     # Build Docker image
make docker-push      # Push to ECR
make push-image       # Build and push

# Deployment
make deploy           # Deploy to EKS
make local-run        # Run locally

# Monitoring
make status           # Check deployment
make logs-driver      # View driver logs
make logs-all         # View all logs

# Testing & Cleanup
make test             # Run unit tests
make clean            # Clean artifacts
```

Example:
```bash
make deploy ENVIRONMENT=staging
make logs-driver ENVIRONMENT=staging
```

## 🤝 Contributing

### Development Workflow

```bash
# Create feature branch
git checkout -b feature/description

# Make changes
vim application/src/job.py

# Test locally
make test
make local-run

# Commit
git add .
git commit -m "type: description"

# Push
git push origin feature/description

# Create Pull Request on GitHub
# After review and merge, Jenkins automatically deploys!
```

### Commit Message Format

```
type: subject

- type: feat, fix, docs, style, refactor, test, chore
- subject: what changed, present tense, no period
- Optionally add body with more details
```

Examples:
```
feat: add country population aggregation
fix: handle empty S3 input gracefully
docs: update README with new features
refactor: optimize groupBy operation
```

## 🔒 Security

- ✅ Docker image runs as non-root user (user 185)
- ✅ IAM roles for S3 access (no hardcoded credentials)
- ✅ EKS RBAC for Spark jobs
- ✅ Secrets not committed to git (.gitignore configured)

## 📈 Scaling

### Horizontal Scaling

```bash
# Increase executors in config/env.prod.sh
export SPARK_EXECUTOR_INSTANCES="10"

# Or update spark-job.yaml
executor:
  instances: 10   # More executors = more parallelism
```

### Vertical Scaling

```bash
# Increase memory/cores in spark-job.yaml
driver:
  memory: 8g      # More per driver
  cores: 4

executor:
  memory: 8g      # More per executor
  cores: 4
```

### EKS Node Scaling

```bash
# Scale worker nodes
eksctl scale nodegroup \
  --cluster=bigdata-dev \
  --name=workers \
  --nodes=5  # or as needed
```

## 💰 Cost

Approximate monthly costs (AWS US-East-1):
- EKS Control Plane: $73
- EC2 (3 m5.xlarge nodes): $216
- S3 Storage: $2-50
- Data Transfer: $0-90
- **Total: ~$300-400/month**

See [infrastructure/README.md](infrastructure/README.md) for cost optimization tips.

## 🐛 Troubleshooting

See detailed troubleshooting guides:
- **Application issues**: [application/README.md](application/README.md#troubleshooting)
- **Infrastructure issues**: [infrastructure/README.md](infrastructure/README.md#troubleshooting)
- **Deployment issues**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md#troubleshooting)

## 📞 Support

```bash
# Check logs
make logs-driver
make logs-all

# Check status
kubectl describe sparkapplication bigdata-job

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check resources
kubectl top pods
kubectl top nodes
```

## 📄 License

This project is licensed under the MIT License.

## 👤 Author

- **Yaw Frimpong** - [yfrimpong1](https://github.com/yfrimpong1)

---

**Last Updated:** February 6, 2026
**Project Version:** 1.0.0