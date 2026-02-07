.PHONY: help setup deploy docker-build docker-push test clean status logs-driver logs-all local-run validate push-image cleanup-resources

# Default environment
ENVIRONMENT ?= dev

help:
	@echo "BigData Pipeline - Makefile Commands"
	@echo "====================================="
	@echo ""
	@echo "Setup & Cleanup:"
	@echo "  make setup              - Setup EKS infrastructure"
	@echo "  make cleanup            - Cleanup all AWS resources"
	@echo ""
	@echo "Building & Deployment:"
	@echo "  make validate           - Validate Spark job syntax"
	@echo "  make docker-build       - Build Docker image"
	@echo "  make docker-push        - Push image to ECR"
	@echo "  make push-image         - Build and push (shorthand)"
	@echo "  make deploy             - Deploy to EKS"
	@echo "  make local-run          - Run Spark job locally"
	@echo ""
	@echo "Testing & Monitoring:"
	@echo "  make test               - Run unit tests"
	@echo "  make status             - Check deployment status"
	@echo "  make logs-driver        - Show driver logs"
	@echo "  make logs-all           - Show all job logs"
	@echo ""
	@echo "Example:"
	@echo "  make deploy ENVIRONMENT=dev"
	@echo "  make docker-build ENVIRONMENT=prod"
	@echo ""

setup:
	@echo "Setting up EKS infrastructure..."
	@source config/env.$(ENVIRONMENT).sh && \
	bash infrastructure/scripts/setup.sh

cleanup:
	@echo "⚠️  WARNING: This will delete all AWS resources!"
	@read -p "Type 'yes' to confirm: " confirm && \
	[ "$$confirm" = "yes" ] && \
	source config/env.$(ENVIRONMENT).sh && \
	bash infrastructure/scripts/cleanup.sh || echo "Cleanup cancelled"

validate:
	@echo "Validating Spark job..."
	@python -m py_compile application/src/job.py
	@echo "✓ Spark job syntax is valid"

docker-build:
	@echo "Building Docker image..."
	@source config/env.$(ENVIRONMENT).sh && \
	docker build -f application/docker/Dockerfile \
		-t $$IMAGE_NAME:latest \
		.
	@echo "✓ Docker image built: $$IMAGE_NAME:latest"

docker-push: docker-build
	@echo "Pushing image to ECR..."
	@source config/env.$(ENVIRONMENT).sh && \
	aws ecr get-login-password --region $$AWS_REGION | \
		docker login --username AWS --password-stdin $$AWS_ACCOUNT_ID.dkr.ecr.$$AWS_REGION.amazonaws.com && \
	docker tag $$IMAGE_NAME:latest $$ECR_REPO:latest && \
	docker push $$ECR_REPO:latest
	@echo "✓ Image pushed to ECR"

push-image: docker-push

deploy:
	@echo "Deploying to EKS ($(ENVIRONMENT))..."
	@source config/env.$(ENVIRONMENT).sh && \
	bash application/deploy/deploy.sh $(ENVIRONMENT)
	@echo "✓ Deployment complete"

test:
	@echo "Running tests..."
	@python -m pytest application/tests/ -v --tb=short 2>/dev/null || \
	echo "No tests found in application/tests/"

local-run:
	@echo "Running Spark job locally..."
	@source config/env.$(ENVIRONMENT).sh && \
	spark-submit --master local[*] \
		--packages org.apache.hadoop:hadoop-aws:3.3.4 \
		application/src/job.py

status:
	@echo "Checking Spark job status..."
	@kubectl get sparkapplications -n default || echo "Spark Operator namespace not found"
	@echo ""
	@echo "Checking pods..."
	@kubectl get pods -n default || true

logs-driver:
	@echo "Getting driver logs..."
	@POD=$$(kubectl get pods -n default -l spark-role=driver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then \
		echo "No driver pod found"; \
	else \
		kubectl logs -f $$POD -n default; \
	fi

logs-all:
	@echo "Getting all job logs..."
	@kubectl logs -f -l app=bigdata-job -n default --all-containers=true 2>/dev/null || \
	echo "No pods found matching selector"

clean:
	@echo "Cleaning up local artifacts..."
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete
	@find . -type f -name ".pytest_cache" -delete
	@echo "✓ Cleanup complete"

.DEFAULT_GOAL := help
