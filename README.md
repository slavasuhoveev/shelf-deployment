# Local Kubernetes Development

Shelf can be run locally in a Minikube Kubernetes cluster using Helm.

The deployment repository contains the Kubernetes infrastructure for:

- `shelf-auth`
- `shelf-api`
- `shelf-front`
- PostgreSQL databases
- database migration jobs
- Kubernetes Services
- health/readiness probes
- Ingress configuration

For local development, service images use the `develop` tag and are loaded
directly into Minikube.

---

## Prerequisites

The following tools must be installed:

- Docker
- kubectl
- Helm
- Minikube
- Make

Verify the installation:

```bash
docker --version
kubectl version --client
helm version
minikube version
make --version
```

Docker must be running:

```bash
docker info
```

---

# Quick Start

## 1. Build service images

Images are built in their respective repositories.

Expected local images:

```text
ghcr.io/slavasuhoveev/shelf-auth:develop
ghcr.io/slavasuhoveev/shelf-api:develop
ghcr.io/slavasuhoveev/shelf-front:develop
```

Build the latest versions before starting the local Kubernetes environment.

The deployment repository does not build application images itself.
Each service owns its Docker build process.

---

## 2. Bootstrap the auth signing key

`shelf-auth` requires an RSA private key for signing JWTs.

This is normally required only during the initial local environment setup.

Generate the key from the `shelf-auth` repository:

```bash
openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:2048 \
  -out devkeys/k1-2025-08-30.pem
```

The filename must correspond to the configured:

```text
SIGNING_KEY_KID=k1-2025-08-30
```

The private key must never be committed to Git.

Start Minikube and create the namespace:

```bash
make minikube-start
make namespace
```

Create the Kubernetes Secret:

```bash
kubectl create secret generic shelf-auth-keys \
  --from-file=k1-2025-08-30.pem=../shelf-auth/devkeys/k1-2025-08-30.pem \
  -n shelf-local
```

Adjust the path to the `shelf-auth` repository if necessary.

Verify:

```bash
kubectl get secret shelf-auth-keys -n shelf-local
```

The key is mounted inside `shelf-auth` at:

```text
/run/secrets/keys
```

---

## 3. Start Shelf

After the initial secret bootstrap, the normal local startup is:

```bash
make local-up
```

This performs:

```text
start Minikube
       ↓
create/verify namespace
       ↓
load local develop images into Minikube
       ↓
lint Helm chart
       ↓
helm upgrade --install
       ↓
show Kubernetes status
```

Check that all application and database Pods are running:

```bash
make pods
```

A healthy environment should look similar to:

```text
shelf-api-...       1/1   Running
shelf-api-db-0      1/1   Running
shelf-auth-...      1/1   Running
shelf-auth-db-0     1/1   Running
shelf-front-...     1/1   Running
```

Migration Jobs should be complete:

```bash
make migrations
```

---

# Access Shelf

For local development, Shelf uses `localhost` through Kubernetes port forwarding.

Start all port forwards:

```bash
make port-forward
```

This exposes:

```text
Frontend: http://localhost:3000
Auth:     http://localhost:8081
API:      http://localhost:8082
```

Open:

```text
http://localhost:3000
```

Keep `make port-forward` running while using the application.

Stop the port forwards with:

```text
Ctrl+C
```

The request flow is:

```text
Browser
   │
   ├── localhost:3000
   │        ↓
   │   port-forward
   │        ↓
   │   shelf-front Service
   │        ↓
   │   shelf-front Pod
   │
   ├── localhost:8081
   │        ↓
   │   port-forward
   │        ↓
   │   shelf-auth Service
   │        ↓
   │   shelf-auth Pod
   │
   └── localhost:8082
            ↓
       port-forward
            ↓
       shelf-api Service
            ↓
       shelf-api Pod
```

Communication between backend services does not use `localhost`.

Inside Kubernetes, services communicate through Kubernetes DNS, for example:

```text
shelf-api
    ↓
http://shelf-auth:8080
```

Databases are accessed in the same way through their Kubernetes Services.

---

# Updating the Local Environment

## Application code changes

After changing one of the services:

1. Rebuild its `develop` Docker image in the service repository.
2. Return to `shelf-deployment`.
3. Reload the images and update the deployment:

```bash
make local-update
```

`local-update` performs:

```text
load local images
       ↓
helm upgrade
       ↓
restart application Deployments
       ↓
wait for rollout
```

Check the result:

```bash
make pods
```

---

## Helm changes

After changing templates or values, first validate them:

```bash
make lint
```

Optionally inspect the generated Kubernetes manifests:

```bash
make template
```

Then apply the changes:

```bash
make upgrade
```

Check:

```bash
make status
```

---

# Useful Commands

Show all available Make commands:

```bash
make help
```

Show the complete local Kubernetes status:

```bash
make status
```

Show Pods:

```bash
make pods
```

Watch Pods:

```bash
make pods-watch
```

Show Services:

```bash
make services
```

Show PVCs:

```bash
make pvc
```

Show migration Jobs:

```bash
make migrations
```

Follow application logs:

```bash
make logs-auth
make logs-api
make logs-front
```

Restart an individual service:

```bash
make restart-auth
make restart-api
make restart-front
```

Restart all application Deployments:

```bash
make restart
```

Wait for all application rollouts:

```bash
make rollout-status
```

Show Helm release status:

```bash
make helm-status
```

---

# Debugging

If a Pod is crashing:

```bash
kubectl get pods -n shelf-local
```

Inspect it:

```bash
kubectl describe pod <pod-name> -n shelf-local
```

Read the current logs:

```bash
kubectl logs <pod-name> -n shelf-local
```

If Kubernetes has already restarted the container, inspect the previous instance:

```bash
kubectl logs <pod-name> -n shelf-local --previous
```

This is particularly useful for `CrashLoopBackOff`.

Check migration logs:

```bash
make migration-logs
```

Check that the auth signing key is mounted:

```bash
kubectl exec -it deployment/shelf-auth -n shelf-local -- \
  ls -la /run/secrets/keys
```

---

# Helm Configuration

The base configuration is stored in:

```text
charts/shelf-app/values.yaml
```

Environment-specific overrides are stored in:

```text
environments/local/values.yaml
environments/dev/values.yaml
```

For the local environment Helm effectively combines:

```text
charts/shelf-app/values.yaml
              +
environments/local/values.yaml
              ↓
final Kubernetes manifests
```

The rendered configuration can be inspected with:

```bash
make template
```

---

# Local Images

The local environment uses:

```text
:develop
```

images.

For example:

```text
ghcr.io/slavasuhoveev/shelf-auth:develop
ghcr.io/slavasuhoveev/shelf-api:develop
ghcr.io/slavasuhoveev/shelf-front:develop
```

Minikube uses its own container runtime/image store.

Therefore, an image built by the host Docker daemon is not automatically
available to Kubernetes running inside Minikube.

The Makefile handles loading the local images with:

```bash
make images-load
```

To inspect the Shelf images available inside Minikube:

```bash
make images-list
```

The local Helm configuration uses:

```yaml
image:
  tag: develop
  pullPolicy: IfNotPresent
```

This allows Kubernetes to use images loaded directly into Minikube instead of
requiring them to be pulled from GHCR.

---

# Ingress

The Helm chart contains Ingress support.

For example, a local Ingress can expose:

```text
front.shelf.local
auth.shelf.local
api.shelf.local
```

The Minikube nginx ingress controller can be enabled with:

```bash
minikube addons enable ingress
```

Check it with:

```bash
kubectl get pods -n ingress-nginx
```

The Ingress itself can be inspected with:

```bash
kubectl get ingress -n shelf-local
```

However, the normal local browser workflow currently uses `localhost`
and port forwarding instead of the HTTP Ingress hostnames.

## Why localhost is used locally

Some browser APIs are available only in a secure context.

For example:

```javascript
crypto.randomUUID()
```

is available on HTTPS pages.

Browsers also treat `localhost` as a special secure-context exception for
local development.

Therefore:

```text
http://localhost:3000
```

can use these APIs, while plain HTTP on:

```text
http://front.shelf.local
```

is not considered a secure context.

For this reason the current local environment uses:

```text
http://localhost:3000
http://localhost:8081
http://localhost:8082
```

The future `dev` environment will use real domains with TLS:

```text
LOCAL
  localhost
  + port-forward

DEV
  real domains
  + Ingress
  + HTTPS/TLS
```

---

# Stop the Environment

Stop Minikube while preserving the cluster:

```bash
make local-down
```

or:

```bash
make minikube-stop
```

Start it again later:

```bash
make minikube-start
```

To completely delete the local cluster:

```bash
make minikube-delete
```

Deleting Minikube removes the local Kubernetes cluster and its local
Kubernetes state, so it should not be part of the normal development workflow.

---

# Typical Local Workflow

After the initial setup, normal development should require only:

```bash
# Build changed service images in their respective repositories.

# Start/update Kubernetes environment:
make local-up

# Expose Shelf to the host:
make port-forward
```

After rebuilding application images:

```bash
make local-update
```

For troubleshooting:

```bash
make status
make logs-auth
make logs-api
make logs-front
```

The goal is for application repositories to own application builds, while
`shelf-deployment` owns the local Kubernetes deployment lifecycle.
