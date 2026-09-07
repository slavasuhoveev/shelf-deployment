# Shelful Deployment

Infrastructure and deployment configuration for **Shelful**.

This repository is the deployment source of truth for the Shelful services:

- `shelf-auth` — authentication and identity service
- `shelf-api` — domain and business API
- `shelf-front` — web application

It contains:

- Kubernetes manifests packaged with Helm
- environment-specific Helm configuration
- Argo CD GitOps configuration
- Terraform AWS infrastructure configuration
- local Kubernetes development tooling

Application source code, tests, Dockerfiles, and container image builds live in
the individual service repositories.

> **Ownership model**
>
> Terraform owns cloud infrastructure.  
> Argo CD owns Kubernetes desired state in cloud environments.  
> Kubernetes controllers own controller-generated resources.  
> Git is the source of truth.

---

## Architecture

Shelful deployment is separated into infrastructure and application layers.

```text
                         GitHub
                           │
          ┌────────────────┴────────────────┐
          │                                 │
   Service repositories             shelf-deployment
          │                                 │
          │ CI                              ├── Terraform
          ▼                                 │      │
        GHCR                                │      ▼
   immutable images                         │     AWS
          │                                 │
          │                                 └── Argo CD
          │                                        │
          │                                        ▼
          └──────────────────────────────► Kubernetes
                                                   │
                                      ┌────────────┼────────────┐
                                      ▼            ▼            ▼
                                  shelf-auth   shelf-api   shelf-front
```

### Infrastructure layer

Terraform manages AWS infrastructure required by the application.

The development infrastructure includes:

```text
VPC
├── Public subnets
├── Private subnets
├── Internet Gateway
├── Route tables
├── Security Groups
├── EKS
│   ├── Managed Node Group
│   ├── EKS Add-ons
│   └── Pod Identity
├── RDS PostgreSQL
├── IAM roles and policies
├── ACM
└── Route 53 integration
```

Terraform does not deploy Shelful application workloads into Kubernetes.

### Application layer

Argo CD manages the Kubernetes application state using Helm.

```text
Git
 ↓
Argo CD
 ↓
Helm
 ↓
Kubernetes API
 ↓
Deployments / Services / Jobs / Ingress
```

For cloud environments, Git contains the desired application state.

---

## Repository Structure

```text
.
├── argocd/
│   ├── applications/
│   │   └── shelf-dev.yaml
│   └── projects/
│       └── shelf.yaml
│
├── charts/
│   └── shelf-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── ...
│
├── environments/
│   ├── dev/
│   │   └── values.yaml
│   └── local/
│       └── values.yaml
│
├── terraform/
│   └── environments/
│       └── dev/
│           ├── *.tf
│           ├── .terraform.lock.hcl
│           └── policies/
│
└── Makefile
```

Terraform file names are organizational only.

All `.tf` files inside a Terraform module directory are loaded as one
configuration.

---

# Deployment Model

## Service CI

Each application repository owns its own CI and Docker image build.

```text
source code
    ↓
tests / lint
    ↓
Docker build
    ↓
push image
    ↓
GHCR
```

Cloud deployments use immutable Git commit SHA image tags.

Example:

```text
ghcr.io/slavasuhoveev/shelf-api:<git-sha>
```

Do not use `latest` for deployed environments.

A running application version must be traceable back to the exact source
commit that produced its container image.

---

## GitOps Deployment

Application versions are deployed by changing the desired state in Git.

```text
1. Merge application changes
          ↓
2. Service CI builds the image
          ↓
3. Image is pushed to GHCR using a Git SHA tag
          ↓
4. Update the image tag in environment values
          ↓
5. Merge the deployment repository change
          ↓
6. Argo CD detects the Git/live-state difference
          ↓
7. Review the Argo CD diff
          ↓
8. Sync the application
          ↓
9. Kubernetes performs the rollout
```

Example:

```yaml
shelfApi:
  image:
    repository: ghcr.io/slavasuhoveev/shelf-api
    tag: "<git-sha>"
```

Changing the image tag in Git is the normal cloud deployment action.

Avoid manual cloud deployment commands such as:

```bash
kubectl set image ...
```

Manual live-cluster changes should be exceptional and reconciled back into Git.

---

# Environment Ownership

Local and cloud environments intentionally use different deployment workflows.

## Local

```text
Make
 ↓
Helm
 ↓
Minikube
```

Direct Helm operations are appropriate for the local development environment.

## Dev / Cloud

```text
Git
 ↓
Argo CD
 ↓
Helm
 ↓
EKS
```

Application changes in cloud environments should go through Git and Argo CD
rather than direct Helm mutations.

## AWS Infrastructure

```text
Terraform
 ↓
AWS Provider
 ↓
AWS API
 ↓
Infrastructure
```

Terraform is responsible for the lifecycle of Terraform-managed cloud
infrastructure.

---

# Local Development

Shelful can be run locally in Minikube.

Prerequisites:

- Docker
- kubectl
- Helm
- Minikube
- Make

Application images use the local `develop` tag:

```text
ghcr.io/slavasuhoveev/shelf-auth:develop
ghcr.io/slavasuhoveev/shelf-api:develop
ghcr.io/slavasuhoveev/shelf-front:develop
```

The deployment repository does not build application images.

Build changed images in their respective service repositories first.

## Initial setup

`shelf-auth` requires an RSA private key for signing JWTs.

The private key must never be committed to Git.

After generating the local signing key in the `shelf-auth` repository, start
Minikube and create the namespace:

```bash
make minikube-start
make namespace
```

Create the local Kubernetes signing-key Secret:

```bash
kubectl create secret generic shelf-auth-keys \
  --from-file=k1-2025-08-30.pem=../shelf-auth/devkeys/k1-2025-08-30.pem \
  -n shelf-local
```

Adjust the path and key identifier when necessary.

## Start Shelful locally

```bash
make local
```

This starts the local Kubernetes environment and exposes:

```text
Frontend: http://localhost:3000
Auth:     http://localhost:8081
API:      http://localhost:8082
```

Alternatively, deploy without starting port forwarding:

```bash
make local-up
```

Then start forwarding separately:

```bash
make port-forward
```

## Update local application images

After rebuilding one or more service images:

```bash
make local-update
```

This reloads the local images into Minikube, upgrades the Helm release,
restarts application Deployments, and waits for rollout completion.

## Local configuration

Base Helm configuration:

```text
charts/shelf-app/values.yaml
```

Local overrides:

```text
environments/local/values.yaml
```

Dev overrides:

```text
environments/dev/values.yaml
```

Conceptually:

```text
charts/shelf-app/values.yaml
              +
environment values
              ↓
rendered Kubernetes manifests
```

---

# Helm

The `shelf-app` chart describes the Kubernetes application.

Environment-independent Kubernetes structure belongs in the chart.

Environment-specific configuration belongs in environment values.

Validate Helm changes with:

```bash
make lint
```

Inspect rendered manifests with:

```bash
make template
```

Typical environment-specific values include:

- image tags
- replica counts
- hostnames
- CORS origins
- resource configuration
- environment-specific feature switches

Secrets must not be committed to Helm values.

---

# Argo CD

Argo CD compares the desired state stored in Git with the live Kubernetes
state.

```text
Desired State (Git)
        ↕
Live State (Kubernetes)
```

Application definitions live under:

```text
argocd/applications/
```

Project-level configuration lives under:

```text
argocd/projects/
```

Typical application states:

```text
Synced
```

Git and Kubernetes match.

```text
OutOfSync
```

The live cluster differs from the desired state in Git.

```text
Healthy
```

The application resources are operational according to Argo CD health
evaluation.

The development environment currently uses manual synchronization:

```text
Git change
    ↓
Argo CD detects OutOfSync
    ↓
Review Diff
    ↓
Sync
    ↓
Synced / Healthy
```

Useful inspection commands:

```bash
make argo-status
make argo-refresh
make argo-diff
```

Synchronization is intentionally explicit:

```bash
argocd app sync shelf-dev
```

---

# Kubernetes and Controller Ownership

Avoid having multiple systems independently manage the same resource.

The ownership model is:

```text
Terraform
    │
    └── Cloud infrastructure

Argo CD + Helm
    │
    └── Kubernetes desired state

Kubernetes controllers
    │
    └── Controller-generated resources
```

For example:

```text
Helm
 ↓
Kubernetes Ingress
 ↓
AWS Load Balancer Controller
 ↓
AWS ALB / Target Groups / related resources
```

The AWS Load Balancer Controller is part of the control path.

External HTTP requests do not pass through the controller.

The application request path is:

```text
Internet
   ↓
Route 53
   ↓
ALB
   ↓
Target
   ↓
Kubernetes Service
   ↓
Pod
```

Controller-generated ALBs and Target Groups should not be independently
managed by Terraform.

---

# Database Migrations

Database migrations run as Kubernetes Jobs.

Current migration jobs exist for:

```text
shelf-auth
shelf-api
```

Inspect them with:

```bash
make migrations
```

Inspect migration logs with:

```bash
make migration-logs
```

Kubernetes Job templates are immutable.

Cloud GitOps deployments should eventually use an explicit migration lifecycle,
such as Argo CD hooks, so migrations run before an incompatible application
version is rolled out.

This improvement is tracked separately from the current deployment setup.

---

# Secrets

Secrets must never be committed to Git in plaintext.

This includes:

- database passwords
- JWT signing private keys
- API tokens
- GitHub credentials
- AWS credentials

Kubernetes `Secret` resources must not be treated as a safe mechanism for
storing plaintext credentials in Git.

A dedicated secret-management solution should be introduced before production.

Possible approaches include:

- AWS Secrets Manager
- External Secrets Operator
- SOPS
- Sealed Secrets

---

# AWS Authentication

Human and workload access must remain separate.

Human access:

```text
Developer
    ↓
IAM Identity Center
    ↓
IAM Role
    ↓
temporary AWS credentials
```

Kubernetes workload access:

```text
Kubernetes ServiceAccount
        ↓
EKS Pod Identity
        ↓
IAM Role
        ↓
AWS API
```

Future CI infrastructure access should use:

```text
GitHub Actions
      ↓
OIDC
      ↓
IAM Role
      ↓
temporary AWS credentials
```

Long-lived AWS access keys should not be introduced where workload identity
can be used instead.

---

# Terraform

Terraform configuration for the AWS development environment lives under:

```text
terraform/environments/dev/
```

The initial Terraform configuration was created by adopting the manually
provisioned AWS development infrastructure.

The normal validation workflow is:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

Equivalent Make targets are provided where appropriate:

```bash
make tf-init
make tf-fmt
make tf-fmt-check
make tf-validate
make tf-check
make tf-plan
```

Always review a Terraform plan before applying infrastructure changes.

For destructive operations, inspect:

```bash
make tf-plan-destroy
```

before explicitly running Terraform destruction.

---

## Terraform State

Terraform state maps Terraform resource addresses to real infrastructure.

```text
Terraform Configuration
        │
        │ desired state
        ▼
Terraform
        │
        ├──── Terraform State
        │
        ▼
Cloud Provider API
        │
        ▼
Actual Infrastructure
```

Terraform state must never be committed to Git.

Ignore:

```gitignore
.terraform/
terraform.tfstate
terraform.tfstate.*
```

Commit:

```text
.terraform.lock.hcl
```

The provider lock file is part of the reproducible Terraform configuration.

The current development setup uses local Terraform state.

A remote backend with state locking and appropriate access controls should be
introduced before collaborative or production infrastructure management.

---

## Existing Infrastructure Adoption

Existing infrastructure can be adopted into Terraform using import.

The safe workflow is:

```text
1. Describe the existing resource in Terraform
2. Import the real resource into Terraform state
3. Run terraform plan
4. Reconcile configuration differences
5. Repeat until the plan is clean
```

The target after adoption is:

```text
Plan: 0 to add, 0 to change, 0 to destroy.
```

Do not blindly apply Terraform immediately after importing existing
infrastructure.

---

# Infrastructure Lifecycle

Normal infrastructure changes should follow:

```text
Terraform code change
        ↓
terraform fmt
        ↓
terraform validate
        ↓
terraform plan
        ↓
review
        ↓
terraform apply
```

Once a resource is Terraform-managed, AWS Console changes should not be the
normal management workflow.

Manual changes can introduce infrastructure drift:

```text
Terraform desired state
        ≠
AWS actual state
```

Emergency manual changes should be reconciled back into Terraform.

---

# Infrastructure Teardown

Environment destruction requires additional care because some AWS resources
can be owned by Kubernetes controllers rather than directly by Terraform.

For example:

```text
Delete Kubernetes Ingress
        ↓
AWS Load Balancer Controller
        ↓
delete ALB / Target Groups
        ↓
verify controller cleanup
        ↓
Terraform destroy
```

Do not delete the EKS cluster first when Kubernetes controllers still own
external AWS resources that require controller cleanup.

Before destroying RDS, explicitly decide whether a final database snapshot is
required.

Always review:

```bash
make tf-plan-destroy
```

before destruction.

After destruction:

```bash
make tf-state
```

should show no Terraform-managed resources for a fully removed environment.

Terraform success does not replace a cloud-resource audit.

Verify at minimum:

```text
EKS
EC2
RDS
Load Balancers
Target Groups
NAT Gateways
EBS volumes
Elastic IPs
VPC
```

Verify intentionally preserved resources separately.

---

# DNS and Domain Lifecycle

Domain registration, authoritative DNS, and application hosting are separate
concerns.

```text
Registrar
    ↓
Domain
    ↓
Authoritative DNS
    ↓
Application endpoint
```

The `shelful.club` domain registration and its Route 53 Hosted Zone are
intentionally preserved independently from the disposable development
environment.

This allows application infrastructure to be destroyed or moved to another
cloud provider without losing the domain.

---

# Useful Commands

Show all available Make targets:

```bash
make help
```

## Local Kubernetes

```bash
make local
make local-up
make local-update
make local-down

make status
make pods
make pods-watch
make services
make pvc

make logs-auth
make logs-api
make logs-front

make migrations
make migration-logs
```

## Helm

```bash
make lint
make template
make helm-status
```

## Terraform

```bash
make tf-init
make tf-fmt
make tf-fmt-check
make tf-validate
make tf-check
make tf-plan
make tf-plan-destroy
make tf-state
```

## Argo CD

```bash
make argo-status
make argo-refresh
make argo-diff
```

Important state-changing operations remain explicit where appropriate.

---

# Operational Principles

1. **Git is the source of truth for cloud application deployments.**
2. **Application images use immutable Git SHA tags in cloud environments.**
3. **Terraform owns Terraform-managed cloud infrastructure.**
4. **Argo CD and Helm own Kubernetes desired state in cloud environments.**
5. **Kubernetes controllers own controller-generated resources.**
6. **Direct Helm deployment is intended for local development, not normal cloud deployment.**
7. **Secrets are never committed in plaintext.**
8. **Terraform plans are reviewed before infrastructure changes.**
9. **Argo CD diffs are reviewed before manual synchronization.**
10. **Manual cloud and cluster changes are exceptional and must be reconciled into code.**
11. **Destructive operations require explicit review and post-destroy verification.**
12. **Infrastructure and deployments should be reproducible from version-controlled configuration.**

---

# Known Technical Debt / TODO

The initial Terraform configuration was created by adopting the first manually
provisioned AWS development environment.

Before recreating the next AWS development environment:

- [ ] Refactor Terraform for clean environment bootstrap and remove dependencies
      on resources and identifiers from the previously imported environment.

The refactoring is tracked as a separate infrastructure task.

Additional production-hardening work will be documented and tracked separately.

---

# Future Improvements

Potential future infrastructure improvements include:

- clean Terraform bootstrap from an empty environment
- remote Terraform state and state locking
- Terraform CI (`fmt`, `validate`, `plan`)
- GitHub Actions OIDC for Terraform
- dedicated secret management
- ExternalDNS evaluation/integration
- automatic Argo CD synchronization where appropriate
- Argo CD migration hooks
- service-specific ALB health checks
- Kubernetes resource requests and limits
- PodDisruptionBudgets where required
- observability and alerting
- database backup and restore strategy
- environment/account separation
- least-privilege IAM hardening
- restricted EKS API access
- production-grade network topology
- reusable Terraform modules where genuine reuse appears

---

# Responsibility Summary

| Layer | Tool | Responsibility |
|---|---|---|
| Application source | GitHub | Service source code |
| CI | GitHub Actions | Test, build, publish images |
| Container registry | GHCR | Immutable application images |
| Deployment configuration | Git | Desired deployment state |
| Kubernetes packaging | Helm | Render Kubernetes manifests |
| GitOps | Argo CD | Reconcile Git with Kubernetes |
| Orchestration | Kubernetes | Run application workloads |
| Cloud infrastructure | Terraform | Provision AWS infrastructure |
| Cloud platform | AWS | EKS, RDS, networking, IAM |
| External HTTP entry | ALB | Route traffic into Kubernetes |
| DNS | Route 53 | Resolve application hostnames |

---

# Core Principle

```text
Application code
      +
Deployment configuration
      +
Infrastructure configuration
      =
Reproducible environment
```

The cloud console is an operational and diagnostic interface.

It is not the source of truth.
