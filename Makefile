# =========================================================
# Shelful Deployment
# =========================================================

SHELL := /bin/bash

# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

RELEASE_NAME ?= shelf-app
CHART ?= ./charts/shelf-app

ENV ?= local
VALUES ?= ./environments/$(ENV)/values.yaml

NAMESPACE ?= shelf-local

MINIKUBE ?= minikube
MINIKUBE_PROFILE ?= minikube
MINIKUBE_DRIVER ?= docker
KUBECTL ?= kubectl
HELM ?= helm
TERRAFORM ?= terraform
ARGOCD ?= argocd

# Terraform
TF_DIR ?= ./terraform/environments/dev

# Argo CD
ARGO_APP ?= shelf-dev
ARGO_PROJECT ?= shelf

# Local application images
AUTH_IMAGE ?= ghcr.io/slavasuhoveev/shelf-auth:develop
API_IMAGE ?= ghcr.io/slavasuhoveev/shelf-api:develop
FRONT_IMAGE ?= ghcr.io/slavasuhoveev/shelf-front:develop

# Local ports
FRONT_PORT ?= 3000
AUTH_PORT ?= 8081
API_PORT ?= 8082


# =========================================================
# Help
# =========================================================

.PHONY: help

help: ## Show available commands
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; \
		{printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'


# =========================================================
# Minikube
# =========================================================

.PHONY: minikube-start
minikube-start: ## Start Minikube
	@$(MINIKUBE) start \
		--profile $(MINIKUBE_PROFILE) \
		--driver $(MINIKUBE_DRIVER)


.PHONY: minikube-stop
minikube-stop: ## Stop Minikube
	@$(MINIKUBE) stop --profile $(MINIKUBE_PROFILE)


.PHONY: minikube-delete
minikube-delete: ## Delete Minikube cluster
	@$(MINIKUBE) delete --profile $(MINIKUBE_PROFILE)


.PHONY: minikube-status
minikube-status: ## Show Minikube status
	@$(MINIKUBE) status --profile $(MINIKUBE_PROFILE)



# =========================================================
# Validation
# =========================================================

.PHONY: check
check: lint tf-check ## Run all static deployment checks


# =========================================================
# Helm validation
# =========================================================

.PHONY: lint
lint: ## Lint Helm chart
	@$(HELM) lint $(CHART) \
		-f $(VALUES)


.PHONY: template
template: ## Render Helm templates
	@$(HELM) template $(RELEASE_NAME) $(CHART) \
		-f $(VALUES)


# =========================================================
# Kubernetes namespace
# =========================================================

.PHONY: namespace
namespace: ## Create namespace if it does not exist
	@$(KUBECTL) create namespace $(NAMESPACE) \
		--dry-run=client \
		-o yaml | $(KUBECTL) apply -f -


# =========================================================
# Local Docker images
# =========================================================

.PHONY: images-load
images-load: ## Load all local Shelful images into Minikube
	@echo "Loading Shelful images into Minikube..."
	@$(MINIKUBE) image load $(AUTH_IMAGE) \
		--profile $(MINIKUBE_PROFILE)
	@$(MINIKUBE) image load $(API_IMAGE) \
		--profile $(MINIKUBE_PROFILE)
	@$(MINIKUBE) image load $(FRONT_IMAGE) \
		--profile $(MINIKUBE_PROFILE)


.PHONY: images-list
images-list: ## Show Shelful images available inside Minikube
	@$(MINIKUBE) image ls \
		--profile $(MINIKUBE_PROFILE) | grep Shelful || true


# =========================================================
# Helm deployment
# =========================================================

.PHONY: require-local
require-local:
	@if [ "$(ENV)" != "local" ]; then \
		echo "ERROR: Direct Helm mutations are allowed only for ENV=local."; \
		echo "Cloud environments must be deployed through Git and Argo CD."; \
		exit 1; \
	fi


.PHONY: install
install: require-local namespace lint ## Install local Shelful Helm release
	@$(HELM) install $(RELEASE_NAME) $(CHART) \
		-f $(VALUES) \
		--namespace $(NAMESPACE)


.PHONY: upgrade
upgrade: require-local lint ## Upgrade existing local Shelful Helm release
	@$(HELM) upgrade $(RELEASE_NAME) $(CHART) \
		-f $(VALUES) \
		--namespace $(NAMESPACE)


.PHONY: deploy
deploy: require-local namespace lint ## Install or upgrade local Shelful
	@$(HELM) upgrade --install $(RELEASE_NAME) $(CHART) \
		-f $(VALUES) \
		--namespace $(NAMESPACE)


.PHONY: uninstall
uninstall: require-local ## Uninstall local Shelful Helm release
	@$(HELM) uninstall $(RELEASE_NAME) \
		--namespace $(NAMESPACE)


.PHONY: helm-status
helm-status: ## Show Helm release status
	@$(HELM) status $(RELEASE_NAME) \
		--namespace $(NAMESPACE)


# =========================================================
# Kubernetes status
# =========================================================

.PHONY: status
status: ## Show Shelful Kubernetes resources
	@echo
	@echo "=== Pods ==="
	@$(KUBECTL) get pods -n $(NAMESPACE)

	@echo
	@echo "=== Services ==="
	@$(KUBECTL) get services -n $(NAMESPACE)

	@echo
	@echo "=== Jobs ==="
	@$(KUBECTL) get jobs -n $(NAMESPACE)

	@echo
	@echo "=== PVCs ==="
	@$(KUBECTL) get pvc -n $(NAMESPACE)

	@echo
	@echo "=== Ingress ==="
	@$(KUBECTL) get ingress -n $(NAMESPACE)


.PHONY: pods
pods: ## Show Shelful pods
	@$(KUBECTL) get pods -n $(NAMESPACE)


.PHONY: pods-watch
pods-watch: ## Watch Shelful pods
	@$(KUBECTL) get pods -n $(NAMESPACE) --watch


.PHONY: services
services: ## Show Shelful services
	@$(KUBECTL) get services -n $(NAMESPACE)


.PHONY: jobs
jobs: ## Show migration jobs
	@$(KUBECTL) get jobs -n $(NAMESPACE)


.PHONY: pvc
pvc: ## Show persistent volume claims
	@$(KUBECTL) get pvc -n $(NAMESPACE)


# =========================================================
# Kubernetes context
# =========================================================

.PHONY: context
context: ## Show current Kubernetes context and namespace
	@echo "Context:"
	@$(KUBECTL) config current-context
	@echo
	@echo "Namespace: $(NAMESPACE)"


# =========================================================
# Rollouts
# =========================================================

.PHONY: restart
restart: require-local ## Restart all local Shelful application deployments
	@$(KUBECTL) rollout restart deployment/shelf-auth \
		-n $(NAMESPACE)
	@$(KUBECTL) rollout restart deployment/shelf-api \
		-n $(NAMESPACE)
	@$(KUBECTL) rollout restart deployment/shelf-front \
		-n $(NAMESPACE)


.PHONY: restart-auth
restart-auth: require-local ## Restart local shelf-auth
	@$(KUBECTL) rollout restart deployment/shelf-auth \
		-n $(NAMESPACE)


.PHONY: restart-api
restart-api: require-local ## Restart local shelf-api
	@$(KUBECTL) rollout restart deployment/shelf-api \
		-n $(NAMESPACE)


.PHONY: restart-front
restart-front: require-local ## Restart local shelf-front
	@$(KUBECTL) rollout restart deployment/shelf-front \
		-n $(NAMESPACE)


.PHONY: rollout-status
rollout-status: ## Wait for application rollouts
	@$(KUBECTL) rollout status deployment/shelf-auth \
		-n $(NAMESPACE)
	@$(KUBECTL) rollout status deployment/shelf-api \
		-n $(NAMESPACE)
	@$(KUBECTL) rollout status deployment/shelf-front \
		-n $(NAMESPACE)


# =========================================================
# Logs
# =========================================================

.PHONY: logs-auth
logs-auth: ## Follow shelf-auth logs
	@$(KUBECTL) logs \
		deployment/shelf-auth \
		-n $(NAMESPACE) \
		-f


.PHONY: logs-api
logs-api: ## Follow shelf-api logs
	@$(KUBECTL) logs \
		deployment/shelf-api \
		-n $(NAMESPACE) \
		-f


.PHONY: logs-front
logs-front: ## Follow shelf-front logs
	@$(KUBECTL) logs \
		deployment/shelf-front \
		-n $(NAMESPACE) \
		-f


# =========================================================
# Port forwarding
# =========================================================

.PHONY: port-forward
port-forward: ## Forward frontend, auth and API ports
	@echo "Starting Shelful port forwards..."
	@echo "Frontend: http://localhost:$(FRONT_PORT)"
	@echo "Auth:     http://localhost:$(AUTH_PORT)"
	@echo "API:      http://localhost:$(API_PORT)"
	@echo
	@trap 'kill 0' INT TERM EXIT; \
		$(KUBECTL) port-forward \
			service/shelf-front \
			$(FRONT_PORT):3000 \
			-n $(NAMESPACE) & \
		$(KUBECTL) port-forward \
			service/shelf-auth \
			$(AUTH_PORT):8080 \
			-n $(NAMESPACE) & \
		$(KUBECTL) port-forward \
			service/shelf-api \
			$(API_PORT):8082 \
			-n $(NAMESPACE) & \
		wait


# =========================================================
# Migration jobs
# =========================================================

.PHONY: migrations
migrations: ## Show migration job status
	@$(KUBECTL) get jobs -n $(NAMESPACE)


.PHONY: migration-logs
migration-logs: ## Show migration job logs
	@echo "=== shelf-auth migration ==="
	@$(KUBECTL) logs job/shelf-auth-migrate \
		-n $(NAMESPACE) || true

	@echo
	@echo "=== shelf-api migration ==="
	@$(KUBECTL) logs job/shelf-api-migrate \
		-n $(NAMESPACE) || true


.PHONY: migrations-delete
migrations-delete: require-local ## Delete local migration jobs so they can be recreated
	@$(KUBECTL) delete job shelf-auth-migrate \
		-n $(NAMESPACE) \
		--ignore-not-found

	@$(KUBECTL) delete job shelf-api-migrate \
		-n $(NAMESPACE) \
		--ignore-not-found


.PHONY: migrations-rerun
migrations-rerun: require-local migrations-delete upgrade ## Delete and recreate local migration jobs
	@$(KUBECTL) get jobs -n $(NAMESPACE)


# =========================================================
# Local development workflow
# =========================================================

.PHONY: local-up
local-up: minikube-start namespace images-load deploy ## Start and deploy local Shelf
	@echo
	@echo "Shelful local Kubernetes environment is deployed."
	@echo
	@$(MAKE) status

.PHONY: local
local: local-up ## Start full local Shelful environment
	@echo
	@echo "Shelful is running:"
	@echo "  Frontend: http://localhost:$(FRONT_PORT)"
	@echo "  Auth:     http://localhost:$(AUTH_PORT)"
	@echo "  API:      http://localhost:$(API_PORT)"
	@echo
	@echo "Press Ctrl+C to stop port forwarding."
	@$(MAKE) port-forward

.PHONY: local-update
local-update: images-load upgrade restart rollout-status ## Reload images and redeploy Shelf
	@echo
	@echo "Shelful local deployment updated."


.PHONY: local-down
local-down: ## Stop local Minikube environment
	@$(KUBECTL) stop --profile $(MINIKUBE_PROFILE)


# =========================================================
# Terraform
# =========================================================

.PHONY: tf-init
tf-init: ## Initialize Terraform
	@$(TERRAFORM) -chdir=$(TF_DIR) init


.PHONY: tf-fmt
tf-fmt: ## Format Terraform configuration
	@$(TERRAFORM) -chdir=$(TF_DIR) fmt -recursive


.PHONY: tf-fmt-check
tf-fmt-check: ## Check Terraform formatting
	@$(TERRAFORM) -chdir=$(TF_DIR) fmt -check -recursive


.PHONY: tf-validate
tf-validate: ## Validate Terraform configuration
	@$(TERRAFORM) -chdir=$(TF_DIR) validate


.PHONY: tf-check
tf-check: tf-fmt-check tf-validate ## Run Terraform static checks


.PHONY: tf-plan
tf-plan: ## Show Terraform execution plan
	@$(TERRAFORM) -chdir=$(TF_DIR) plan


.PHONY: tf-plan-destroy
tf-plan-destroy: ## Preview Terraform environment destruction
	@$(TERRAFORM) -chdir=$(TF_DIR) plan -destroy


.PHONY: tf-state
tf-state: ## List resources managed by Terraform
	@$(TERRAFORM) -chdir=$(TF_DIR) state list


# =========================================================
# Argo CD
# =========================================================

.PHONY: argo-status
argo-status: ## Show Argo CD application status
	@$(ARGOCD) app get $(ARGO_APP)


.PHONY: argo-refresh
argo-refresh: ## Refresh Argo CD application state
	@$(ARGOCD) app get $(ARGO_APP) --refresh


.PHONY: argo-diff
argo-diff: ## Show Git vs live Kubernetes differences
	@$(ARGOCD) app diff $(ARGO_APP)
