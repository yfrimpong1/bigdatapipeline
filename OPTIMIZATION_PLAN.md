# BigData Pipeline - Optimization & Reorganization Plan

## Current State Analysis

### ✅ What's Working
- Solid Spark job logic (`job.py`)
- Professional README.md with architecture
- Functional Jenkinsfile with build automation
- Good foundation with empty directories ready for organization

### ⚠️ Current Issues
1. **Mixed structure**: Files scattered at root + empty organized directories
2. **No environment separation**: No dev/staging/prod configs
3. **No build automation**: Manual steps required for deployment
4. **Limited documentation**: No deployment or development guides
5. **Configuration hardcoded**: AWS credentials and paths in scripts
6. **JAR files at root**: Dependencies not organized
7. **Orphaned directories**: `scripts/`, `data/`, `docs/`, `config/`, `.jenkins/` are empty

---

## Optimization Strategy

### Phase 1: Smart Organization (Keep It Simple)

Move files to logical directories while keeping the existing Jenkinsfile working:

```
BigDataPipeline/
├── application/                    # Application code
│   ├── src/
│   │   └── job.py                 # Main Spark job
│   ├── docker/
│   │   └── Dockerfile             # Container definition
│   ├── deploy/
│   │   ├── deploy.sh              # Deployment script
│   │   └── spark-job.yaml         # K8s manifest
│   └── README.md                  # Development guide
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
├── config/                        # Environment configs
│   ├── env.dev.sh                # Dev environment
│   ├── env.staging.sh            # Staging environment
│   └── env.prod.sh               # Production environment
│
├── data/                          # Sample/test data
│   ├── countries.csv
│   ├── yawbdata-raw.json
│   └── yawbdata-processed.json
│
├── docs/                          # Documentation
│   ├── DEPLOYMENT.md             # Deployment guide
│   ├── ARCHITECTURE.md           # Architecture details
│   └── TROUBLESHOOTING.md        # Common issues
│
├── .jenkins/                      # Jenkins configuration
│   ├── Jenkinsfile               # App deployment (auto-trigger)
│   └── Jenkinsfile.infra         # Infra setup (manual)
│
├── libs/                          # Dependencies (JARs)
│   ├── aws-java-sdk-bundle-1.12.262.jar
│   └── hadoop-aws-3.3.4.jar
│
├── Makefile                       # Build automation
├── README.md                      # Project overview
└── .gitignore                    # Already configured
```

---

### Phase 2: Key Improvements

#### 1. **Environment Configuration**
```bash
# config/env.dev.sh
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=336107977801
export CLUSTER_NAME=bigdata-dev
export IMAGE_NAME=bigdata-job
export ECR_REPO=336107977801.dkr.ecr.us-east-1.amazonaws.com/bigdata-job
```

#### 2. **Build Automation (Makefile)**
```makefile
.PHONY: setup deploy docker-build docker-push test clean

setup:
	bash infrastructure/scripts/setup.sh

deploy:
	bash application/deploy/deploy.sh

docker-build:
	docker build -f application/docker/Dockerfile -t $(IMAGE_NAME):latest .

docker-push:
	docker tag $(IMAGE_NAME):latest $(ECR_REPO):latest
	docker push $(ECR_REPO):latest
```

#### 3. **Separation of Concerns**
- **`.jenkins/Jenkinsfile`**: Application deployment (frequent, low risk)
  - Trigger: On every push to main
  - Steps: Build → Push → Deploy
  
- **`.jenkins/Jenkinsfile.infra`**: Infrastructure setup (rare, high risk)
  - Trigger: Manual approval only
  - Steps: Verify → Setup EKS → Install Spark Operator

#### 4. **Decentralized Documentation**
- **`README.md`**: Project overview & quick start
- **`application/README.md`**: Developer guide
- **`infrastructure/README.md`**: Infra setup guide
- **`docs/DEPLOYMENT.md`**: Detailed deployment procedures

---

## Reorganization Steps

### Step 1: Move Application Files
```bash
mv job.py application/src/
mv dockerfile application/docker/Dockerfile
mv deploy.sh application/deploy/
mv spark-job.yaml application/deploy/
```

### Step 2: Move Infrastructure Files
```bash
mv aws_infrastructure.sh infrastructure/scripts/setup.sh
mv cleanup.sh infrastructure/scripts/
mv spark-role.yaml infrastructure/kubernetes/rbac/
mv spark-rolebinding.yaml infrastructure/kubernetes/rbac/
mv SparkS3AccessPolicy.json infrastructure/aws/iam-policy.json
```

### Step 3: Move Data Files
```bash
mv countries.csv data/
mv yawbdata-raw.json data/
mv yawbdata-processed.json data/
```

### Step 4: Move Jenkins Files
```bash
mv Jenkinsfile .jenkins/
# Create .jenkins/Jenkinsfile.infra for infrastructure setup
```

### Step 5: Move Dependencies
```bash
mkdir -p libs
mv aws-java-sdk-bundle-1.12.262.jar libs/
mv hadoop-aws-3.3.4.jar libs/
```

### Step 6: Create Configuration Files
```bash
# config/env.dev.sh
# config/env.staging.sh
# config/env.prod.sh
```

### Step 7: Create Makefile
```bash
# Makefile with 15+ targets for automation
```

### Step 8: Create Documentation
```bash
# docs/DEPLOYMENT.md - Manual & Jenkins deployment
# infrastructure/README.md - Infrastructure setup
# application/README.md - Development guide
```

---

## Benefits of This Organization

| Aspect | Before | After |
|--------|--------|-------|
| **Navigation** | 20+ files at root | Logical directory structure |
| **Scalability** | Hard to extend | Easy to add new microservices |
| **CI/CD** | Single monolithic pipeline | Separate concerns (app vs infra) |
| **Configuration** | Hardcoded values | Environment-specific configs |
| **Documentation** | Single README | Modular guides per component |
| **Deployment** | Manual steps | Automated with Makefile |
| **Dependencies** | Mixed with code | Organized in libs/ |

---

## Implementation Plan

### Option A: Manual (Recommended)
1. Create directories (already done)
2. Move files one category at a time
3. Update paths in scripts
4. Create config files
5. Create Makefile
6. Test with `make deploy ENVIRONMENT=dev`
7. Commit to git

### Option B: Automated (One Command)
```bash
bash reorganize.sh
```
(Creates a script that does everything)

---

## Migration Checklist

- [ ] Move application files
- [ ] Move infrastructure files
- [ ] Move data files
- [ ] Create config files (env.dev.sh, env.staging.sh, env.prod.sh)
- [ ] Update paths in deploy.sh
- [ ] Update paths in Dockerfile
- [ ] Update Jenkinsfile paths
- [ ] Create .jenkins/Jenkinsfile.infra
- [ ] Create Makefile
- [ ] Create docs/DEPLOYMENT.md
- [ ] Create infrastructure/README.md
- [ ] Create application/README.md
- [ ] Update main README.md
- [ ] Test deployment locally with `make deploy`
- [ ] Commit changes to git

---

## Next Steps

Would you like me to:
1. **Execute the reorganization** - Move all files to new structure
2. **Create a reorganization script** - One command to do everything
3. **Proceed gradually** - One category at a time with validation
4. **Keep current state** - Only create documentation for manual moves

Choose one and I'll proceed!
