# Application Development Guide

Complete guide for developing, testing, and extending the BigData Spark application.

## Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Local Development Setup](#local-development-setup)
4. [Running Locally](#running-locally)
5. [Developing the Job](#developing-the-job)
6. [Testing](#testing)
7. [Docker & Deployment](#docker--deployment)
8. [Monitoring](#monitoring)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The BigData application is a **PySpark job** that:

- **Reads** raw data from S3 (`s3a://yawbdata-raw/input/`)
- **Processes** data using PySpark (grouping, aggregation, transformations)
- **Writes** processed results to S3 (`s3a://yawbdata-processed/output/`)
- **Runs** on Kubernetes via Spark Operator
- **Deploys** via Jenkins or manual commands

---

## Project Structure

```
application/
├── src/
│   └── job.py                    # Main Spark job (PySpark code)
├── docker/
│   ├── Dockerfile                # Container definition
│   └── entrypoint.sh             # Container startup script (optional)
├── deploy/
│   ├── deploy.sh                 # Deployment automation script
│   └── spark-job.yaml            # Kubernetes SparkApplication manifest
├── tests/
│   ├── test_job.py               # Unit tests for job logic
│   ├── conftest.py               # pytest configuration and fixtures
│   └── data/                      # Test data files
├── requirements.txt              # Python dependencies
└── README.md                      # This file
```

---

## Local Development Setup

### Prerequisites

```bash
# Python 3.8 or higher
python3 --version  # Should output 3.8+

# Git (for version control)
git --version

# Optional: Docker (for testing containers)
docker --version
```

### Install Dependencies

```bash
cd /Users/yfrimpong/DevOps/BigDataPipeline

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# or: venv\Scripts\activate  (Windows)

# Install PySpark and dependencies
pip install -r application/requirements.txt

# Verify installation
python -c "import pyspark; print(f'PySpark {pyspark.__version__}')"
```

### Development Tools (Optional)

```bash
# For code quality
pip install pylint flake8 black

# For testing
pip install pytest pytest-cov

# For Jupyter notebooks
pip install jupyter jupyterlab
```

---

## Running Locally

### Option 1: Using spark-submit

```bash
# Source environment
source config/env.dev.sh

# Run with AWS credentials (for S3 access)
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret

# Submit job
spark-submit \
  --master local[*] \
  --packages org.apache.hadoop:hadoop-aws:3.3.4 \
  application/src/job.py

# Expected output:
# 24/02/06 10:00:00 INFO SparkSession: Created SparkSession
# [Your job output]
```

### Option 2: Using Python directly

```bash
# From project root
python application/src/job.py

# Or with virtual environment
source venv/bin/activate
python application/src/job.py
```

### Option 3: Using Docker (Recommended)

```bash
# Build Docker image
make docker-build ENVIRONMENT=dev

# Run Docker container
docker run \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  bigdata-job:latest

# Or using make
make local-run ENVIRONMENT=dev
```

### Option 4: Using Make (Easiest)

```bash
# One-command local run
make local-run ENVIRONMENT=dev

# This:
# 1. Validates syntax
# 2. Sources environment config
# 3. Runs spark-submit with correct classpath
```

---

## Developing the Job

### Current Job Logic

Located in `application/src/job.py`:

```python
from pyspark.sql import SparkSession

# Create Spark session
spark = SparkSession.builder.appName("BigDataJob").getOrCreate()

# Read data from S3
df = spark.read.csv("s3a://yawbdata-raw/input/", header=True)

# Transform: count by country
df.groupBy("country").count().write.mode("overwrite") \
  .parquet("s3a://yawbdata-processed/output/")

# Cleanup
spark.stop()
```

### Editing the Job

```bash
# 1. Edit in your favorite editor
vim application/src/job.py

# 2. Test locally
make local-run ENVIRONMENT=dev

# 3. Check for errors
make validate

# 4. Run unit tests
make test

# 5. Commit changes
git add application/src/job.py
git commit -m "feature: add new transformation"

# 6. Push (triggers automatic deployment)
git push origin main
```

### Common Modifications

#### Add Dependencies

```bash
# 1. Add to requirements.txt
echo "pandas==1.5.0" >> application/requirements.txt

# 2. Dockerfile uses pip install, so automatic on build
# (See application/docker/Dockerfile)

# 3. Commit
git add application/requirements.txt
git commit -m "Add pandas dependency"
```

#### Change S3 Paths

```python
# In job.py
# OLD:
input_path = "s3a://yawbdata-raw/input/"
output_path = "s3a://yawbdata-processed/output/"

# NEW:
input_path = "s3a://my-bucket/data/input/"
output_path = "s3a://my-bucket/data/output/"

# Or use environment variables:
import os
input_path = os.getenv("INPUT_PATH", "s3a://yawbdata-raw/input/")
output_path = os.getenv("OUTPUT_PATH", "s3a://yawbdata-processed/output/")
```

#### Add Complex Transformations

```python
# Example: Filter and aggregate with multiple groups
df = spark.read.csv("s3a://yawbdata-raw/input/", header=True)

# Filter: Only countries with population > 10M
large_countries = df.filter(df.Population > 10000000)

# Aggregate: Count and average by region
result = large_countries \
  .groupBy("Region") \
  .agg(
    F.count("*").alias("country_count"),
    F.avg("Population").alias("avg_population"),
    F.max("GDP").alias("max_gdp")
  )

# Write results
result.write.mode("overwrite").parquet(output_path)
```

#### Add Logging

```python
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Log progress
logger.info(f"Starting job processing {df.count()} records")
logger.info(f"Grouping by {grouping_column}")
logger.info(f"Writing to {output_path}")
```

#### Handle Errors

```python
try:
  df = spark.read.csv(input_path, header=True)
  result = df.groupBy("country").count()
  result.write.mode("overwrite").parquet(output_path)
except FileNotFoundError as e:
  logger.error(f"Input file not found: {e}")
  spark.stop()
  exit(1)
except Exception as e:
  logger.error(f"Unexpected error: {e}")
  spark.stop()
  exit(1)
finally:
  spark.stop()
```

---

## Testing

### Unit Testing

```bash
# Run all tests
make test

# Or manually
python -m pytest application/tests/ -v

# With coverage
python -m pytest application/tests/ --cov=application/src --cov-report=html

# Run specific test
python -m pytest application/tests/test_job.py::test_groupby_operation -v
```

### Example Test File

Create `application/tests/test_job.py`:

```python
import pytest
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

@pytest.fixture(scope="module")
def spark():
    """Create Spark session for tests"""
    return SparkSession.builder \
        .appName("TestJob") \
        .master("local[*]") \
        .config("spark.sql.shuffle.partitions", "4") \
        .getOrCreate()

@pytest.fixture
def sample_data(spark):
    """Create sample DataFrame for testing"""
    data = [
        ("USA", 331000000, "North America"),
        ("Canada", 38000000, "North America"),
        ("Mexico", 128000000, "North America"),
        ("Brazil", 215000000, "South America"),
        ("Argentina", 46000000, "South America"),
    ]
    columns = ["country", "population", "region"]
    return spark.createDataFrame(data, columns)

def test_dataframe_creation(spark):
    """Test that DataFrame can be created"""
    assert spark is not None

def test_read_csv(spark):
    """Test reading CSV file"""
    # Create sample CSV
    sample_csv = """country,population
USA,331000000
Canada,38000000"""
    
    # Write to temp file
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
        f.write(sample_csv)
        temp_path = f.name
    
    # Read
    df = spark.read.csv(temp_path, header=True)
    assert df.count() == 2

def test_groupby_operation(sample_data):
    """Test groupBy transformation"""
    result = sample_data.groupBy("region").count()
    assert result.count() == 2  # Two regions

def test_aggregation(sample_data):
    """Test aggregation functions"""
    result = sample_data \
        .groupBy("region") \
        .agg(F.sum("population").alias("total_pop"))
    
    # Check results
    assert result.count() == 2
    assert result.schema.names == ["region", "total_pop"]

def test_filter_operation(sample_data):
    """Test filtering"""
    filtered = sample_data.filter(sample_data.population > 100000000)
    assert filtered.count() == 3  # USA, Mexico, Brazil

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
```

### Testing Best Practices

- Test with small datasets
- Use fixtures for reusable resources
- Mock external dependencies (S3)
- Test edge cases (empty data, nulls)
- Keep tests isolated and independent
- Document test purpose with docstrings

---

## Docker & Deployment

### Building Docker Image

```bash
# Using make (recommended)
make docker-build ENVIRONMENT=dev

# Or manually
docker build -f application/docker/Dockerfile \
  -t bigdata-job:latest \
  .

# Verify
docker images | grep bigdata-job
```

### Dockerfile Structure

The Dockerfile in `application/docker/Dockerfile`:

```dockerfile
FROM apache/spark-py:latest          # Spark 3.x with Python
USER root                            # Need root to install
COPY ../../libs/*.jar /opt/spark/jars/  # Add S3 connectivity JARs
ENV SPARK_DIST_CLASSPATH="..."      # Configure classpath
WORKDIR /app
COPY src/job.py .                    # Copy your job code
RUN chmod 644 /opt/spark/jars/*.jar  # Fix permissions
USER 185                             # Run as non-root (security)
```

### Pushing to ECR

```bash
# Using make
make docker-push ENVIRONMENT=dev

# Or manually
source config/env.dev.sh
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker tag bigdata-job:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

---

## Kubernetes Deployment

### Deploy to EKS

```bash
# Option 1: Using make
make deploy ENVIRONMENT=dev

# Option 2: Manual
source config/env.dev.sh
bash application/deploy/deploy.sh dev

# Option 3: Jenkins
git push origin main  # Automatic deployment triggered
```

### Kubernetes Manifest (`spark-job.yaml`)

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: bigdata-job
spec:
  type: Python
  pythonVersion: "3"
  mode: cluster
  sparkVersion: "3.5.0"
  image: <ECR-URL>/bigdata-job:latest
  mainApplicationFile: local:///app/job.py
  
  driver:
    cores: 1
    memory: 2g
  
  executor:
    cores: 2
    instances: 3
    memory: 2g
```

### Scaling

```yaml
# Increase parallelism
executor:
  cores: 4          # More cores per executor
  instances: 5      # More executors (total workers)
  memory: 4g        # More memory

# Enable dynamic allocation
dynamicAllocation:
  enabled: true
  minExecutors: 2
  maxExecutors: 10
```

---

## Monitoring

### Check Job Status

```bash
# Get all jobs
kubectl get sparkapplications

# Describe specific job
kubectl describe sparkapplication bigdata-job

# Check pods
kubectl get pods -l spark-app-selector=bigdata-job
```

### View Logs

```bash
# Using make
make logs-driver    # Driver (main) logs
make logs-all       # All job logs

# Or manually
kubectl logs -f bigdata-job-driver
kubectl logs -f bigdata-job-exec-1
```

### Performance Metrics

```bash
# CPU and memory
kubectl top pods
kubectl top nodes

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

---

## Troubleshooting

### Local Run Fails

```bash
# Check syntax
python -m py_compile application/src/job.py

# Check imports
python -c "import pyspark; import sys; print(sys.version)"

# Run with debug
python -u application/src/job.py 2>&1
```

### Docker Build Fails

```bash
# Check dependencies exist
ls -la application/docker/
ls -la application/src/
ls -la libs/

# Build with verbose output
docker build -f application/docker/Dockerfile --progress=plain .
```

### Job Fails on K8s

```bash
# Check logs
kubectl logs -f bigdata-job-driver

# Check pod events
kubectl describe pod bigdata-job-driver

# Check cluster resources
kubectl describe nodes
```

### S3 Access Denied

```bash
# Verify credentials in pod
kubectl exec -it bigdata-job-driver -- \
  env | grep AWS

# Test S3 from pod
kubectl exec -it bigdata-job-driver -- \
  aws s3 ls s3://yawbdata-raw/
```

---

## Git Workflow

```bash
# Standard development workflow
git checkout -b feature/new-transformation
vim application/src/job.py
make test
make local-run
git add application/src/job.py
git commit -m "Add new transformation"
git push origin feature/new-transformation

# Create Pull Request on GitHub
# After approval and merge to main:
# Jenkins automatically deploys!
```

---

## Quick Reference

```bash
# Common commands
make validate              # Check syntax
make local-run             # Test locally
make test                  # Run unit tests
make docker-build          # Build container
make docker-push           # Push to ECR
make deploy                # Deploy to EKS
make status                # Check status
make logs-driver           # View logs
make clean                 # Cleanup artifacts
```

---

## Next Steps

- Read [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) for deployment details
- Check [infrastructure/README.md](../infrastructure/README.md) for EKS setup
- See [README.md](../README.md) for project overview
