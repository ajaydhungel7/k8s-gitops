# k8s-gitops — Space Explorer

A production-grade GitOps project demonstrating a full DevOps lifecycle with AWS EKS, Argo CD, Jenkins, Helm, Terraform, and Terragrunt.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS EKS Cluster                       │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Frontend │───▶│ Backend  │───▶│  Redis   │              │
│  │  (Nginx) │    │(FastAPI) │    │  Cache   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│        │               │                                    │
│        │         ┌──────────┐                              │
│        │         │ MongoDB  │                              │
│        │         │   (DB)   │                              │
│        │         └──────────┘                              │
│        │                                                    │
│  ┌──────────┐    ┌──────────┐                              │
│  │  ArgoCD  │    │ Jenkins  │                              │
│  │ (GitOps) │    │  (CI/CD) │                              │
│  └──────────┘    └──────────┘                              │
└─────────────────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
    GitHub Repo           AWS ECR
   (Helm values)        (Docker images)
```

## CI/CD Pipeline Flow

```
Code Push
    │
    ▼
Jenkins (path-based trigger)
    │
    ├── app/** ──▶ Backend Pipeline
    │               ├── Unit Tests
    │               ├── Integration Tests
    │               ├── Code Quality (flake8 + bandit)
    │               ├── Docker Build (multi-stage)
    │               ├── Image Scan (Trivy)
    │               ├── Push to ECR
    │               └── Update Helm values ──▶ ArgoCD sync
    │
    └── frontend/** ──▶ Frontend Pipeline
                    ├── Code Quality (ESLint)
                    ├── Docker Build (multi-stage + Nginx)
                    ├── Image Scan (Trivy)
                    ├── Push to ECR
                    └── Update Helm values ──▶ ArgoCD sync
```

**Branch to environment mapping:**
- `dev` → dev
- `staging` → staging
- `prod` → prod

## GitOps Flow

```
Terraform/Terragrunt
    │
    ▼
Bootstrap Argo CD only
    │
    ▼
Root Argo Application
    │
    ▼
Helm app-of-apps chart (`argocd/apps`)
    │
    ├── platform apps        ──▶ kube-system / external-secrets / jenkins
    └── workload apps        ──▶ k8s-gitops-{env}
```

`argocd/apps/values-<env>.yaml` is the single source of truth. Each file lists `platformApplications` and `workloadApplications`, and pins Argo CD to the matching Git branch for that environment.

## Stack

| Component | Technology |
|-----------|-----------|
| Frontend | React 18 + Vite + Tailwind CSS |
| Backend | Python FastAPI |
| Cache | Redis (Bitnami Helm chart) |
| Database | MongoDB (Bitnami Helm chart) |
| CI/CD | Jenkins (Kubernetes dynamic agents) |
| GitOps | ArgoCD |
| Infrastructure | AWS EKS + VPC + ECR + Secrets Manager |
| Secrets | External Secrets Operator |
| IaC | Terraform + Terragrunt |

## Prerequisites

- AWS account with sufficient permissions (EKS, VPC, ECR, Secrets Manager, IAM)
- [Terraform](https://www.terraform.io/) >= 1.5.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/) >= 3.12
- [Docker](https://www.docker.com/) >= 24.0
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0

## Setup Instructions

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/k8s-gitops.git
cd k8s-gitops
```

### 2. Configure AWS credentials

```bash
aws configure
# Or use IAM Identity Center / environment variables
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
```

### 3. Create Terraform state backend

```bash
# Create S3 bucket for state
aws s3 mb s3://k8s-gitops-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket k8s-gitops-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name k8s-gitops-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 4. Provision infrastructure with Terragrunt

```bash
cd terraform/environments/dev/eks-addons
terragrunt init
terragrunt plan
terragrunt apply
```

Run the other Terragrunt stacks for the environment first so the cluster, VPC, IAM, ECR, and secrets exist before `eks-addons`.

### 5. Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name k8s-gitops-dev
kubectl get nodes  # verify
```

### 6. Update environment metadata and apply the Argo CD root app

```bash
# Checkout the matching environment branch first, then update repoURL and IRSA/VPC placeholders in argocd/apps/values-dev.yaml
# Then apply the matching bootstrap root app
kubectl apply -f argocd/bootstrap/root-app-dev.yaml -n argocd
```

Argo CD will render and sync all platform and workload applications from the metadata in `argocd/apps/values-dev.yaml`.

### 7. Configure Jenkins

1. Get the Jenkins admin password:
   ```bash
   kubectl exec -n jenkins deployment/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
   ```
2. Port-forward to access the UI:
   ```bash
   kubectl port-forward -n jenkins svc/jenkins 8080:8080
   ```
3. Add credentials in Jenkins:
   - `github-token`: GitHub personal access token with repo write permission
   - `slack-webhook`: Slack incoming webhook URL

### 8. Push code to trigger the first pipeline run

```bash
git checkout -b feature/initial-deploy
git push origin feature/initial-deploy
```

Push changes to the branch that matches the environment you want to reconcile. Argo CD will only watch that branch for that environment, so pushes to `dev` affect only dev, pushes to `staging` affect only staging, and pushes to `prod` affect only prod.

## Adding a New Environment

1. Create a new Terraform environment under `terraform/environments/newenv/` (copy from `dev/` and adjust sizing)
2. Add Helm values files: `helm/backend/values-newenv.yaml`, `helm/frontend/values-newenv.yaml`, etc.
3. Add `argocd/apps/values-newenv.yaml` with the environment's app metadata
4. Add a matching bootstrap root app under `argocd/bootstrap/`
5. Run Terragrunt to provision the infrastructure
6. Apply the environment root app

## How Secrets Rotation Works

1. Secrets are stored in AWS Secrets Manager, encrypted with KMS
2. The External Secrets Operator (ESO) runs in the cluster and holds an IRSA role allowing it to read secrets
3. An `ExternalSecret` CRD in each namespace tells ESO which secret paths to sync and into which Kubernetes Secret keys
4. ESO refreshes secrets every 1 hour (configurable via `refreshInterval`)
5. When you rotate a secret in AWS Secrets Manager, ESO picks up the new value on next refresh and updates the Kubernetes Secret
6. Pods that mount the Kubernetes Secret as env vars will pick up the new value on their next restart

## Local Development with Docker Compose

```bash
# Start all services
docker compose up -d

# Backend runs on http://localhost:8000
# Frontend runs on http://localhost:3000

# View logs
docker compose logs -f backend

# Run backend tests locally
docker compose exec backend pytest tests/

# Tear down
docker compose down -v
```

## Repository Structure

```
k8s-gitops/
├── terraform/              # Infrastructure as Code
│   ├── modules/            # Reusable Terraform modules
│   │   ├── vpc/
│   │   ├── eks-cluster/
│   │   ├── ecr/
│   │   ├── iam/
│   │   ├── secrets/
│   │   └── eks-addons/     # Bootstrap only: installs Argo CD
│   └── environments/       # Per-environment Terraform configs
│       ├── dev/
│       ├── staging/
│       └── prod/
├── app/                    # Python FastAPI backend
│   ├── main.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── tests/
├── frontend/               # React + Vite frontend
│   ├── src/
│   ├── Dockerfile
│   └── nginx.conf
├── helm/                   # Helm charts
│   ├── backend/
│   ├── frontend/
│   └── frontend/
├── argocd/                 # Argo CD GitOps metadata and bootstrap apps
│   ├── bootstrap/
│   └── apps/
│   ├── staging/
│   └── prod/
├── jenkins/
│   └── Jenkinsfile
└── docker-compose.yml
```
