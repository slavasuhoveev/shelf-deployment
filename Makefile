# =========================================================
# Shelf Deployment
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

MINIKUBE_PROFILE ?= minikube
MINIKUBE_DRIVER ?= docker

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
	@minikube start \
		--profile $(MINIKUBE_PROFILE) \
		--driver $(MINIKUBE_DRIVER)


.PHONY: minikube-stop
minikube-stop: ## Stop Minikube
	@minikube stop --profile $(MINIKUBE_PROFILE)


.PHONY: minikube-delete
minikube-delete: ## Delete Minikube cluster
	@minikube delete --profile $(MINIKUBE_PROFILE)


.PHONY: minikube-status
minikube-status: ## Show Minikube status
	@minikube status --profile $(MINIKUBE_PROFILE)


# =========================================================
# Helm validation
# =========================================================

.PHONY: lint
lint: ## Lint Helm chart
	@helm lint $(CHART) \
		-f $(VALUES)


.PHONY: template
template: ## Render Helm templates
	@helm template $(RELEASE_NAME) $(CHART) \
		-f $(VALUES)


# =========================================================
# Kubernetes namespace
# =========================================================

.PHONY: namespace
namespace: ## Create namespace if it does not exist
	@kubectl create namespace $(NAMESPACE) \
		--dry-run=client \
		-o yaml | kubectl apply -f -


# =========================================================
# Local Docker images
# =========================================================

.PHONY: images-load
images-load: ## Load all local Shelf images into Minikube
	@echo "Loading Shelf images into Minikube..."
	@minikube image load $(AUTH_IMAGE) \
		--profile $(MINIKUBE_PROFILE)
	@minikube image load $(API_IMAGE) \
		--profile $(MINIKUBE_PROFILE)
	@minikube image load $(FRONT_IMAGE) \
		--profile $(MINIKUBE_PROFILE)


.PHONY: images-list
images-list: ## Show Shelf images available inside Minikube
	@minikube image ls \
		--profile $(MINIKUBE_PROFILE) | grep shelf || true


# =========================================================
# Helm deployment
# =========================================================

.PHONY: install
install: namespace lint ## Install Shelf Helm release
	@helm install $(RELEASE_NAME) $(CHART) \
		-f $(VALUES) \
		--namespace $(NAMESPACE)


.PHONY: upgrade
upgrade: lint ## Upgrade existing Shelf Helm release
	@helm upgrade $(RELEASE_NAME) $(CHART) \
		-f $(VALUES) \
		--namespace $(NAMESPACE)


.PHONY: deploy
deploy: namespace lint ## Install or upgrade Shelf
	@helm upgrade --install $(RELEASE_NAME) $(CHART) \
		-f $(VALUES) \
		--namespace $(NAMESPACE)


.PHONY: uninstall
uninstall: ## Uninstall Shelf Helm release
	@helm uninstall $(RELEASE_NAME) \
		--namespace $(NAMESPACE)


.PHONY: helm-status
helm-status: ## Show Helm release status
	@helm status $(RELEASE_NAME) \
		--namespace $(NAMESPACE)


# =========================================================
# Kubernetes status
# =========================================================

.PHONY: status
status: ## Show Shelf Kubernetes resources
	@echo
	@echo "=== Pods ==="
	@kubectl get pods -n $(NAMESPACE)

	@echo
	@echo "=== Services ==="
	@kubectl get services -n $(NAMESPACE)

	@echo
	@echo "=== Jobs ==="
	@kubectl get jobs -n $(NAMESPACE)

	@echo
	@echo "=== PVCs ==="
	@kubectl get pvc -n $(NAMESPACE)

	@echo
	@echo "=== Ingress ==="
	@kubectl get ingress -n $(NAMESPACE)


.PHONY: pods
pods: ## Show Shelf pods
	@kubectl get pods -n $(NAMESPACE)


.PHONY: pods-watch
pods-watch: ## Watch Shelf pods
	@kubectl get pods -n $(NAMESPACE) --watch


.PHONY: services
services: ## Show Shelf services
	@kubectl get services -n $(NAMESPACE)


.PHONY: jobs
jobs: ## Show migration jobs
	@kubectl get jobs -n $(NAMESPACE)


.PHONY: pvc
pvc: ## Show persistent volume claims
	@kubectl get pvc -n $(NAMESPACE)


# =========================================================
# Rollouts
# =========================================================

.PHONY: restart
restart: ## Restart all Shelf application deployments
	@kubectl rollout restart deployment/shelf-auth \
		-n $(NAMESPACE)
	@kubectl rollout restart deployment/shelf-api \
		-n $(NAMESPACE)
	@kubectl rollout restart deployment/shelf-front \
		-n $(NAMESPACE)


.PHONY: restart-auth
restart-auth: ## Restart shelf-auth
	@kubectl rollout restart deployment/shelf-auth \
		-n $(NAMESPACE)


.PHONY: restart-api
restart-api: ## Restart shelf-api
	@kubectl rollout restart deployment/shelf-api \
		-n $(NAMESPACE)


.PHONY: restart-front
restart-front: ## Restart shelf-front
	@kubectl rollout restart deployment/shelf-front \
		-n $(NAMESPACE)


.PHONY: rollout-status
rollout-status: ## Wait for application rollouts
	@kubectl rollout status deployment/shelf-auth \
		-n $(NAMESPACE)
	@kubectl rollout status deployment/shelf-api \
		-n $(NAMESPACE)
	@kubectl rollout status deployment/shelf-front \
		-n $(NAMESPACE)


# =========================================================
# Logs
# =========================================================

.PHONY: logs-auth
logs-auth: ## Follow shelf-auth logs
	@kubectl logs \
		deployment/shelf-auth \
		-n $(NAMESPACE) \
		-f


.PHONY: logs-api
logs-api: ## Follow shelf-api logs
	@kubectl logs \
		deployment/shelf-api \
		-n $(NAMESPACE) \
		-f


.PHONY: logs-front
logs-front: ## Follow shelf-front logs
	@kubectl logs \
		deployment/shelf-front \
		-n $(NAMESPACE) \
		-f


# =========================================================
# Port forwarding
# =========================================================

.PHONY: port-forward
port-forward: ## Forward frontend, auth and API ports
	@echo "Starting Shelf port forwards..."
	@echo "Frontend: http://localhost:$(FRONT_PORT)"
	@echo "Auth:     http://localhost:$(AUTH_PORT)"
	@echo "API:      http://localhost:$(API_PORT)"
	@echo
	@trap 'kill 0' INT TERM EXIT; \
		kubectl port-forward \
			service/shelf-front \
			$(FRONT_PORT):3000 \
			-n $(NAMESPACE) & \
		kubectl port-forward \
			service/shelf-auth \
			$(AUTH_PORT):8080 \
			-n $(NAMESPACE) & \
		kubectl port-forward \
			service/shelf-api \
			$(API_PORT):8082 \
			-n $(NAMESPACE) & \
		wait


# =========================================================
# Migration jobs
# =========================================================

.PHONY: migrations
migrations: ## Show migration job status
	@kubectl get jobs -n $(NAMESPACE)


.PHONY: migration-logs
migration-logs: ## Show migration job logs
	@echo "=== shelf-auth migration ==="
	@kubectl logs job/shelf-auth-migrate \
		-n $(NAMESPACE) || true

	@echo
	@echo "=== shelf-api migration ==="
	@kubectl logs job/shelf-api-migrate \
		-n $(NAMESPACE) || true


.PHONY: migrations-delete
migrations-delete: ## Delete migration jobs so they can be recreated
	@kubectl delete job shelf-auth-migrate \
		-n $(NAMESPACE) \
		--ignore-not-found

	@kubectl delete job shelf-api-migrate \
		-n $(NAMESPACE) \
		--ignore-not-found


.PHONY: migrations-rerun
migrations-rerun: migrations-delete upgrade ## Delete and recreate migration jobs
	@kubectl get jobs -n $(NAMESPACE)


# =========================================================
# Local development workflow
# =========================================================

.PHONY: local-up
local-up: minikube-start namespace images-load deploy ## Start and deploy local Shelf
	@echo
	@echo "Shelf local Kubernetes environment is deployed."
	@echo
	@$(MAKE) status

.PHONY: local
local: local-up ## Start full local Shelf environment
	@echo
	@echo "Shelf is running:"
	@echo "  Frontend: http://localhost:$(FRONT_PORT)"
	@echo "  Auth:     http://localhost:$(AUTH_PORT)"
	@echo "  API:      http://localhost:$(API_PORT)"
	@echo
	@echo "Press Ctrl+C to stop port forwarding."
	@$(MAKE) port-forward

.PHONY: local-update
local-update: images-load upgrade restart rollout-status ## Reload images and redeploy Shelf
	@echo
	@echo "Shelf local deployment updated."


.PHONY: local-down
local-down: ## Stop local Minikube environment
	@minikube stop --profile $(MINIKUBE_PROFILE)
