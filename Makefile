SHELL := /usr/bin/env bash
.ONESHELL:
.DEFAULT_GOAL := help

AWS_REGION       ?= eu-west-3
AWS_PROFILE      ?= urbanmove
export AWS_PROFILE
PROJECT          ?= urbanmove
ENV              ?= dev
TF_DIR           := infra/terraform
TFVARS           := envs/$(ENV).tfvars
CLUSTER_NAME     ?= $(PROJECT)-$(ENV)-eks
ECR_REGISTRY      = $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null).dkr.ecr.$(AWS_REGION).amazonaws.com

SERVICES := simulator mobility-api identity-fleet analytics-dashboard stream-processor ml-training dashboard-web db-migrate

GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
RESET := \033[0m

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'

.PHONY: init plan apply destroy fmt validate
init:
	cd $(TF_DIR) && terraform init

plan:
	cd $(TF_DIR) && terraform plan -var-file=$(TFVARS)

apply:
	cd $(TF_DIR) && terraform apply -var-file=$(TFVARS) -auto-approve

destroy:
	@read -p "Type DESTROY to confirm full teardown: " ack; \
	[ "$$ack" = "DESTROY" ] || exit 1
	cd $(TF_DIR) && terraform destroy -var-file=$(TFVARS) -auto-approve

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

validate:
	cd $(TF_DIR) && terraform validate

.PHONY: up down demo demo-full
up:
	cd $(TF_DIR) && terraform apply -var-file=$(TFVARS) \
		-var="expensive_on=true" -var="demo_mode=false" -auto-approve
	@$(MAKE) kubeconfig
	@echo "$(GREEN)Dev environment up.$(RESET) Remember: make down when done."

down:
	cd $(TF_DIR) && terraform apply -var-file=$(TFVARS) \
		-var="expensive_on=false" -var="demo_mode=false" -auto-approve
	@echo "$(YELLOW)Expensive resources torn down.$(RESET)"

demo:
	@echo "$(GREEN)==> Phase 1/6: terraform apply (expensive_on, demo_mode off — flip with make sagemaker-deploy)$(RESET)"
	cd $(TF_DIR) && terraform apply -var-file=$(TFVARS) \
		-var="expensive_on=true" -var="demo_mode=false" -auto-approve
	@$(MAKE) kubeconfig
	@echo "$(GREEN)==> Phase 2/6: build + push images to ECR$(RESET)"
	@$(MAKE) docker-build docker-push
	@echo "$(GREEN)==> Phase 3/6: run Alembic migrations$(RESET)"
	@$(MAKE) migrate
	@echo "$(GREEN)==> Phase 4/6: seed IoT cert + Cognito demo user$(RESET)"
	@$(MAKE) seed
	@echo "$(GREEN)==> Phase 5/6: helm install services$(RESET)"
	@$(MAKE) helm-install
	@echo "$(GREEN)==> Phase 6/6: smoke test$(RESET)"
	@$(MAKE) smoke
	@echo ""
	@echo "$(GREEN)Demo stack live.$(RESET)"
	@cd $(TF_DIR) && \
		echo "  dashboard_url    = $$(terraform output -raw dashboard_url 2>/dev/null || echo TBD)" && \
		echo "  mobility_api     = $$(kubectl -n urbanmove get ingress mobility-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo TBD)" && \
		echo "  cognito_pool_id  = $$(terraform output -raw cognito_user_pool_id)"

.PHONY: kubeconfig
kubeconfig:
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)

.PHONY: ecr-login docker-build docker-push
ecr-login:
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(ECR_REGISTRY)

docker-build:
	@echo "$(GREEN)Building + pushing $(words $(SERVICES)) images (linux/amd64)…$(RESET)"
	@$(MAKE) ecr-login >/dev/null
	@docker buildx ls | grep -q urbanmove-builder || \
		docker buildx create --name urbanmove-builder --use --bootstrap >/dev/null
	@docker buildx use urbanmove-builder >/dev/null
	@for svc in $(SERVICES); do \
		if [ "$$svc" = "dashboard-web" ]; then \
			$(MAKE) -s dashboard-build & \
		else \
			echo "  → $$svc"; \
			docker buildx build --quiet --platform=linux/amd64 \
				-t $(ECR_REGISTRY)/$(PROJECT)/$$svc:latest --push apps/$$svc > /dev/null & \
		fi; \
	done; \
	wait

dashboard-build:
	@echo "  → dashboard-web (with Cognito + API URLs from Terraform)"
	@cd $(TF_DIR); \
	POOL_ID=$$(terraform output -raw cognito_user_pool_id); \
	CLIENT_ID=$$(terraform output -raw cognito_dashboard_client_id); \
	cd ../..; \
	docker buildx build --quiet --platform=linux/amd64 \
		--build-arg NEXT_PUBLIC_COGNITO_REGION=$(AWS_REGION) \
		--build-arg "NEXT_PUBLIC_COGNITO_USER_POOL_ID=$$POOL_ID" \
		--build-arg "NEXT_PUBLIC_COGNITO_CLIENT_ID=$$CLIENT_ID" \
		--build-arg "NEXT_PUBLIC_API_BASE=http://localhost:8000" \
		--build-arg "NEXT_PUBLIC_WS_URL=ws://localhost:8001/ws/alerts" \
		-t $(ECR_REGISTRY)/$(PROJECT)/dashboard-web:latest \
		--push apps/dashboard-web > /dev/null

docker-push:
	@echo "$(GREEN)Images pushed by buildx during docker-build (no separate push needed).$(RESET)"

.PHONY: migrate seed seed-cert seed-cognito config-map
config-map:
	@cd $(TF_DIR); \
	kubectl create namespace urbanmove --dry-run=client -o yaml | kubectl apply -f -; \
	kubectl -n urbanmove create configmap urbanmove-config \
		--from-literal=AWS_REGION=$(AWS_REGION) \
		--from-literal=AWS_DEFAULT_REGION=$(AWS_REGION) \
		--from-literal=DB_HOST=$$(terraform output -raw aurora_endpoint) \
		--from-literal=DB_PORT=5432 \
		--from-literal=DB_NAME=urbanmove \
		--from-literal=DB_SECRET_ID=$$(terraform output -raw db_secret_arn) \
		--from-literal=COGNITO_REGION=$(AWS_REGION) \
		--from-literal=COGNITO_USER_POOL_ID=$$(terraform output -raw cognito_user_pool_id) \
		--from-literal=COGNITO_APP_CLIENT_ID=$$(terraform output -raw cognito_dashboard_client_id) \
		--from-literal=KINESIS_STREAM=$$(terraform output -raw kinesis_stream_name) \
		--from-literal=REDIS_URL=redis://$$(terraform output -raw redis_endpoint 2>/dev/null || echo '<not-set>'):6379 \
		--from-literal=IOT_CERT_SECRET_ID=$(PROJECT)-$(ENV)/iot/simulator-cert \
		--dry-run=client -o yaml | kubectl apply -f -

migrate: config-map
	helm upgrade --install db-migrate deploy/helm/db-migrate \
		-f deploy/helm/values-db-migrate.yaml \
		--set image.repository=$(ECR_REGISTRY)/$(PROJECT)/db-migrate \
		--namespace urbanmove --wait --timeout 5m

seed: seed-cert seed-cognito

seed-cert:
	python3 scripts/bootstrap-device-cert.py \
		--project $(PROJECT) --environment $(ENV) --region $(AWS_REGION)

seed-cognito:
	@cd $(TF_DIR); \
	python3 ../../scripts/seed-cognito-user.py \
		--user-pool-id $$(terraform output -raw cognito_user_pool_id) \
		--region $(AWS_REGION)

.PHONY: sagemaker-deploy
sagemaker-deploy:
	@echo "$(GREEN)==> Training + uploading ETA model$(RESET)"
	@python3 -m pip install --quiet --break-system-packages scikit-learn pandas joblib boto3 numpy pyarrow
	@cd $(TF_DIR); \
	BUCKET=$$(terraform output -raw lake_bucket); \
	cd ../..; \
	python3 scripts/train-and-package-eta.py --bucket $$BUCKET --region $(AWS_REGION)
	@echo ""
	@echo "$(GREEN)==> Wiring mobility-api to the endpoint$(RESET)"
	@cd $(TF_DIR); \
	EP=$$(terraform output -raw sagemaker_endpoint_name 2>/dev/null || echo ""); \
	if [ -z "$$EP" ] || [ "$$EP" = "null" ]; then \
		echo "$(YELLOW)WARN: SageMaker endpoint not in TF outputs. Did you apply with demo_mode=true?$(RESET)"; \
		exit 1; \
	fi; \
	kubectl -n urbanmove patch configmap urbanmove-config \
		--type merge -p "{\"data\":{\"SAGEMAKER_ETA_ENDPOINT\":\"$$EP\"}}"
	@kubectl -n urbanmove rollout restart deploy/mobility-api
	@kubectl -n urbanmove rollout status deploy/mobility-api --timeout=2m
	@echo "$(GREEN)mobility-api now uses the SageMaker endpoint for /eta.$(RESET)"

.PHONY: helm-install port-forward
helm-install: config-map
	@for svc in mobility-api identity-fleet analytics-dashboard stream-processor dashboard-web simulator; do \
		echo "$(GREEN)→ $$svc$(RESET)"; \
		helm upgrade --install $$svc deploy/helm/common-service \
			-f deploy/helm/common-service/values.yaml \
			-f deploy/helm/values-$$svc.yaml \
			--set image.repository=$(ECR_REGISTRY)/$(PROJECT)/$$svc \
			--namespace urbanmove --wait --timeout 5m; \
	done

port-forward:
	@echo "$(GREEN)Port-forwards: dashboard at http://localhost:3000$(RESET)"
	@echo "  mobility-api      → :8000"
	@echo "  analytics-dashboard → :8001"
	@echo "  dashboard-web      → :3000"
	@echo "$(YELLOW)Ctrl+C to stop all forwards.$(RESET)"
	@( kubectl -n urbanmove port-forward svc/mobility-api 8000:80 & \
	   kubectl -n urbanmove port-forward svc/analytics-dashboard 8001:80 & \
	   kubectl -n urbanmove port-forward svc/dashboard-web 3000:80 & \
	   wait )

.PHONY: smoke loadtest seed-simulator
smoke:
	@echo "$(GREEN)→ healthz on every service$(RESET)"
	@for svc in mobility-api identity-fleet analytics-dashboard; do \
		kubectl -n urbanmove exec deploy/$$svc -- \
			python -c "import urllib.request; print('$$svc', urllib.request.urlopen('http://localhost:8000/healthz').read().decode())" || true; \
	done
	@echo "$(GREEN)→ pod health$(RESET)"
	@kubectl -n urbanmove get pods -o wide

seed-simulator:
	kubectl -n urbanmove scale deploy/simulator --replicas=1

loadtest:
	k6 run loadtest/k6/smoke.js

.PHONY: lint test local-up local-down
lint:
	@for svc in simulator mobility-api identity-fleet analytics-dashboard stream-processor ml-training; do \
		(cd apps/$$svc && python -m ruff check .) || true; \
	done
	@(cd apps/dashboard-web && npm run lint) || true

test:
	@for svc in mobility-api identity-fleet analytics-dashboard stream-processor simulator; do \
		(cd apps/$$svc && python -m pytest -q) || true; \
	done

local-up:
	docker compose up -d
	@echo "$(GREEN)Local services:$(RESET)"
	@echo "  postgres://urbanmove:urbanmove@localhost:5432/urbanmove"
	@echo "  redis://localhost:6379"
	@echo "  mqtt://localhost:1883"
	@echo "  aws --endpoint-url=http://localhost:4566 (LocalStack)"

local-down:
	docker compose down -v
