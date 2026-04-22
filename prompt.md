# Claude Code Prompt — k8s-gitops Project

## Project Overview

Build a production grade GitOps project called **k8s-gitops** that demonstrates a full DevOps lifecycle with the following stack:

- **Frontend**: React with Vite and Tailwind CSS
- **Backend**: Python FastAPI
- **Cache**: Redis (installed on Kubernetes via Bitnami Helm chart)
- **Database**: MongoDB (installed on Kubernetes via Bitnami Helm chart)
- **CI/CD**: Jenkins (installed on Kubernetes via Helm)
- **GitOps**: ArgoCD (installed on Kubernetes via Helm)
- **Infrastructure**: AWS EKS, VPC, ECR, Secrets Manager with KMS — all provisioned via Terraform
- **Secrets**: External Secrets Operator syncing from AWS Secrets Manager into Kubernetes Secrets
- **Environments**: dev, staging, prod — each with their own Helm values files and Kubernetes namespaces

---

## Application — Space Explorer

The application is called **Space Explorer**. It fetches NASA astronomy pictures of the day, caches results in Redis, persists data in MongoDB, and allows users to favourite and annotate explorations.

### Backend Endpoints

```
GET  /health              — liveness probe — always returns 200
GET  /ready               — readiness probe — returns 503 during warmup, checks Redis and MongoDB
GET  /explore             — fetch today NASA picture, check Redis cache first, save to MongoDB
GET  /explore/{date}      — fetch NASA picture for specific date
GET  /history             — return all explorations from MongoDB
POST /explore/favourite   — mark an exploration as favourite
DELETE /explore/{date}/favourite — remove from favourites
GET  /favourites          — get all favourited explorations
POST /explore/note        — add a personal note to an exploration
```

### Frontend Pages

```
Home page     — shows today NASA picture, cache indicator badge
Explore page  — date picker to fetch past dates
History page  — all past explorations in a grid
Favourites    — starred explorations
```

### Application Behaviour

- On startup the app waits for `WARMUP_SECONDS` (env var, default 30) before marking itself ready
- `/ready` returns 503 during warmup and also checks Redis and MongoDB connectivity
- `/health` always returns 200 — app is alive even during warmup
- `/explore` checks Redis cache first with key `apod:{date}` and TTL 60 seconds
- Cache miss fetches from NASA APOD API: `https://api.nasa.gov/planetary/apod?api_key={NASA_API_KEY}`
- Results are saved to MongoDB using upsert on the date field
- Usage events sent to Metronome asynchronously after each response — never blocks user
- Chat and exploration history uses soft deletes — deleted_at timestamp, never hard delete
- Stripe customer and Metronome customer created on signup even for free tier users

---

## Repository Structure

```
k8s-gitops/
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── eks/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── ecr/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── iam/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── secrets/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── environments/
│       ├── dev/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   ├── backend.tf
│       │   └── terraform.tfvars.example
│       ├── staging/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── backend.tf
│       └── prod/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── backend.tf
├── app/
│   ├── main.py
│   ├── database.py
│   ├── cache.py
│   ├── nasa.py
│   ├── models.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── tests/
│       ├── __init__.py
│       ├── test_unit.py
│       └── test_integration.py
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── Navbar.jsx
│   │   │   ├── ExplorationCard.jsx
│   │   │   ├── CacheBadge.jsx
│   │   │   └── LoadingSpinner.jsx
│   │   ├── pages/
│   │   │   ├── Home.jsx
│   │   │   ├── Explore.jsx
│   │   │   ├── History.jsx
│   │   │   └── Favourites.jsx
│   │   ├── api/
│   │   │   └── client.js
│   │   ├── App.jsx
│   │   └── main.jsx
│   ├── public/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   ├── vite.config.js
│   └── tailwind.config.js
├── helm/
│   ├── backend/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   ├── values-prod.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       ├── hpa.yaml
│   │       ├── configmap.yaml
│   │       ├── serviceaccount.yaml
│   │       └── externalsecret.yaml
│   ├── frontend/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   ├── values-prod.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── ingress.yaml
│   ├── mongodb/
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   └── values-prod.yaml
│   └── redis/
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-staging.yaml
│       └── values-prod.yaml
├── argocd/
│   ├── root-app.yaml
│   ├── dev/
│   │   ├── backend-app.yaml
│   │   ├── frontend-app.yaml
│   │   ├── mongodb-app.yaml
│   │   └── redis-app.yaml
│   ├── staging/
│   │   ├── backend-app.yaml
│   │   ├── frontend-app.yaml
│   │   ├── mongodb-app.yaml
│   │   └── redis-app.yaml
│   └── prod/
│       ├── backend-app.yaml
│       ├── frontend-app.yaml
│       ├── mongodb-app.yaml
│       └── redis-app.yaml
├── jenkins/
│   └── Jenkinsfile
├── docker-compose.yml
├── .gitignore
└── README.md
```

---

## Terraform Specifications

### VPC Module

- Two public subnets across two availability zones
- Two private subnets across two availability zones
- Internet Gateway for public subnets
- NAT Gateway in one public subnet for private subnet outbound access
- Route tables for public and private subnets
- Tag all subnets for EKS discovery:
  - Public subnets: `kubernetes.io/role/elb = 1`
  - Private subnets: `kubernetes.io/role/internal-elb = 1`

### EKS Module

- EKS cluster version 1.30
- Managed node group in private subnets
- Node instance type: t3.medium for dev, t3.large for staging and prod
- Min size 1, max size 3 for dev — min 2 max 5 for staging — min 3 max 10 for prod
- Enable OIDC provider for IRSA
- Install the following via Helm as part of Terraform using the helm provider:
  - AWS Load Balancer Controller — for ALB Ingress
  - External Secrets Operator — for syncing secrets from AWS Secrets Manager
  - Metrics Server — for HPA
  - ArgoCD — GitOps controller
  - Jenkins — CI/CD server

### ECR Module

- Two repositories: `k8s-gitops-backend` and `k8s-gitops-frontend`
- Image scanning on push enabled
- Lifecycle policy: keep last 10 images, delete untagged images after 1 day

### Secrets Module

- One KMS key with key rotation enabled — used to encrypt all secrets
- KMS alias: `alias/k8s-gitops-{environment}-secrets`
- AWS Secrets Manager secret for Redis: `/{project}/{environment}/redis/password`
  - Value: `{ "password": var.redis_password }`
- AWS Secrets Manager secret for MongoDB: `/{project}/{environment}/mongodb/credentials`
  - Value: `{ "username": "admin", "password": var.mongodb_password }`
- All secrets encrypted with the KMS key

### IAM Module

- IRSA role for External Secrets Operator
  - Trust policy: allow EKS OIDC provider to assume the role
  - Permissions: `secretsmanager:GetSecretValue` and `kms:Decrypt` on the secrets and KMS key
- IRSA role for Jenkins
  - Permissions: `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:PutImage`, `ecr:BatchCheckLayerAvailability`, `ecr:CompleteLayerUpload`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`
  - Also permission to update EKS deployments

### Remote State

- S3 bucket for Terraform state: `k8s-gitops-terraform-state`
- DynamoDB table for state locking: `k8s-gitops-terraform-locks`
- Each environment stores state at a different key:
  - dev: `dev/terraform.tfstate`
  - staging: `staging/terraform.tfstate`
  - prod: `prod/terraform.tfstate`

---

## Helm Chart Specifications

### Backend Helm Chart — values per environment

```yaml
# values.yaml — base defaults
replicaCount: 1

image:
  repository: ""
  tag: "latest"
  pullPolicy: Always

service:
  type: ClusterIP
  port: 8000

ingress:
  enabled: true
  className: alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

hpa:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 15
  periodSeconds: 5
  failureThreshold: 3

env:
  WARMUP_SECONDS: "30"
  ENVIRONMENT: "dev"
  NASA_API_KEY: "DEMO_KEY"
  MONGODB_DB: "space_explorer"
  CACHE_TTL: "60"
```

```yaml
# values-dev.yaml
replicaCount: 1
ingress:
  host: dev.k8s-gitops.example.com
env:
  WARMUP_SECONDS: "10"
  ENVIRONMENT: "dev"
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
hpa:
  minReplicas: 1
  maxReplicas: 3
```

```yaml
# values-staging.yaml
replicaCount: 2
ingress:
  host: staging.k8s-gitops.example.com
env:
  WARMUP_SECONDS: "20"
  ENVIRONMENT: "staging"
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
hpa:
  minReplicas: 2
  maxReplicas: 5
```

```yaml
# values-prod.yaml
replicaCount: 3
ingress:
  host: k8s-gitops.example.com
env:
  WARMUP_SECONDS: "30"
  ENVIRONMENT: "prod"
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
hpa:
  minReplicas: 3
  maxReplicas: 10
```

### ExternalSecret template

The backend Helm chart must include an ExternalSecret resource that syncs Redis and MongoDB credentials from AWS Secrets Manager into a Kubernetes Secret:

```yaml
# helm/backend/templates/externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ .Release.Name }}-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: {{ .Release.Name }}-secrets
    creationPolicy: Owner
  data:
    - secretKey: REDIS_PASSWORD
      remoteRef:
        key: /k8s-gitops/{{ .Values.env.ENVIRONMENT }}/redis/password
        property: password
    - secretKey: MONGODB_PASSWORD
      remoteRef:
        key: /k8s-gitops/{{ .Values.env.ENVIRONMENT }}/mongodb/credentials
        property: password
    - secretKey: MONGODB_USERNAME
      remoteRef:
        key: /k8s-gitops/{{ .Values.env.ENVIRONMENT }}/mongodb/credentials
        property: username
```

### MongoDB values per environment

Use the Bitnami MongoDB Helm chart. Key values differences:

```yaml
# values-dev.yaml — single replica, small storage
architecture: standalone
auth:
  enabled: true
  rootUser: admin
  existingSecret: backend-secrets
persistence:
  size: 5Gi
resources:
  requests:
    cpu: 100m
    memory: 256Mi

# values-staging.yaml
architecture: standalone
persistence:
  size: 10Gi
resources:
  requests:
    cpu: 250m
    memory: 512Mi

# values-prod.yaml — replica set for high availability
architecture: replicaset
replicaCount: 3
persistence:
  size: 20Gi
resources:
  requests:
    cpu: 500m
    memory: 1Gi
backup:
  enabled: true
```

### Redis values per environment

Use the Bitnami Redis Helm chart:

```yaml
# values-dev.yaml — standalone
architecture: standalone
auth:
  enabled: true
  existingSecret: backend-secrets
  existingSecretPasswordKey: REDIS_PASSWORD
master:
  persistence:
    size: 1Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi

# values-staging.yaml
architecture: standalone
master:
  persistence:
    size: 2Gi

# values-prod.yaml — sentinel for high availability
architecture: sentinel
sentinel:
  enabled: true
master:
  persistence:
    size: 5Gi
```

---

## ArgoCD Application Specifications

### Root App of Apps

```yaml
# argocd/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: k8s-gitops-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/{YOUR_USERNAME}/k8s-gitops
    targetRevision: main
    path: argocd
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Per environment per service application

Each ArgoCD application should:
- Point to the correct Helm chart path
- Use the correct values file for its environment
- Deploy to the correct namespace: `k8s-gitops-{environment}`
- Have automated sync with selfHeal enabled for dev and staging
- Have manual sync for prod — no automated sync

Example for backend dev:

```yaml
# argocd/dev/backend-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/{YOUR_USERNAME}/k8s-gitops
    targetRevision: main
    path: helm/backend
    helm:
      valueFiles:
        - values.yaml
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: k8s-gitops-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Jenkins Pipeline Specifications

### Dynamic pod agents

Jenkins runs on Kubernetes and uses dynamic pod agents. Each build spins up a pod with the required containers and destroys it after.

### Jenkinsfile

The pipeline must:

1. Use dynamic Kubernetes pod agents with these containers:
   - `python:3.11` for running tests
   - `docker:dind` for building Docker images
   - `amazon/aws-cli` for pushing to ECR and updating manifests
   - `alpine/git` for Git operations

2. Detect which service changed using path based triggers:
   - Changes in `app/**` trigger the backend pipeline
   - Changes in `frontend/**` trigger the frontend pipeline

3. Pipeline stages in order:

```
Stage 1: Checkout
  — git checkout the code

Stage 2: Unit Tests
  — container: python
  — pip install -r requirements.txt
  — pytest tests/test_unit.py -v --junitxml=unit-test-results.xml
  — publish junit results

Stage 3: Integration Tests
  — container: python
  — spin up dependencies using docker compose
  — wait for services to be healthy
  — run pytest tests/test_integration.py -v
  — tear down docker compose

Stage 4: Code Quality
  — container: python
  — run flake8 for linting
  — run bandit for security scanning
  — fail pipeline if critical issues found

Stage 5: Docker Build
  — container: docker
  — multi stage docker build
  — tag with git commit SHA and branch name
  — tag with environment name

Stage 6: Image Scan
  — container: docker
  — install trivy
  — trivy image --exit-code 1 --severity HIGH,CRITICAL {image}
  — fail pipeline if critical vulnerabilities found

Stage 7: Push to ECR
  — container: aws-cli
  — aws ecr get-login-password
  — docker push to ECR with commit SHA tag
  — docker push with latest tag

Stage 8: Update Helm Values
  — container: git
  — update values-{environment}.yaml with new image tag
  — git commit and push to trigger ArgoCD

Stage 9: Notify
  — send Slack notification on success or failure
  — include environment, service, image tag, and build URL
```

4. Branch to environment mapping:
   - `feature/*` branches → deploy to dev
   - `staging` branch → deploy to staging
   - `main` branch → deploy to prod with manual approval gate before Stage 8

5. Use Jenkins credentials for:
   - AWS credentials via IRSA — no hardcoded keys
   - GitHub token for pushing manifest updates
   - Slack webhook URL

---

## Dockerfile Specifications

### Backend Dockerfile — multi stage

```dockerfile
# Stage 1: builder
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: runtime
FROM python:3.11-slim
WORKDIR /app

# non root user for security
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appgroup . .

USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Frontend Dockerfile — multi stage with Nginx

```dockerfile
# Stage 1: build React app
FROM node:20-alpine as builder
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: serve with Nginx
FROM nginx:1.25-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

RUN addgroup -S nginx && adduser -S nginx -G nginx

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s \
  CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### Nginx config for frontend

The Nginx config must proxy `/api/*` requests to the backend service internally:

```nginx
server {
    listen 80;
    
    location /health {
        return 200 'healthy';
        add_header Content-Type text/plain;
    }

    location /api/ {
        proxy_pass http://backend-service:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }
}
```

---

## Frontend Specifications

### Tech stack

- React 18 with Vite
- Tailwind CSS for styling
- React Router v6 for navigation
- Axios for API calls
- Dark space theme — black and dark blue background, white text, gold accents

### Key components

**CacheBadge** — shows whether response came from Redis cache or fresh NASA fetch:
- Green badge with lightning icon: "From Cache"
- Blue badge with satellite icon: "Fresh from NASA"

**ExplorationCard** — displays a NASA picture with:
- Full width image
- Title and date
- Truncated explanation with expand button
- Heart button for favouriting
- Notes input and save button
- Cache badge in top right corner

**Home page** — loads today's exploration automatically on mount, shows the ExplorationCard

**Explore page** — date picker input, fetch button, shows ExplorationCard for selected date

**History page** — grid of all explorations from MongoDB, sorted newest first

**Favourites page** — grid of only favourited explorations

### API client

All API calls go to `/api` which Nginx proxies to the backend:

```javascript
// frontend/src/api/client.js
import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  timeout: 15000
})

export const exploreToday = () => api.get('/explore')
export const exploreDate = (date) => api.get(`/explore/${date}`)
export const getHistory = () => api.get('/history')
export const getFavourites = () => api.get('/favourites')
export const addFavourite = (date) => api.post('/explore/favourite', { date })
export const removeFavourite = (date) => api.delete(`/explore/${date}/favourite`)
export const addNote = (date, note) => api.post('/explore/note', { date, note })
```

---

## Docker Compose for Local Development

```yaml
version: '3.8'
services:
  backend:
    build: ./app
    ports:
      - "8000:8000"
    environment:
      - MONGODB_URL=mongodb://admin:password@mongodb:27017
      - REDIS_URL=redis://:password@redis:6379
      - WARMUP_SECONDS=5
      - NASA_API_KEY=DEMO_KEY
      - ENVIRONMENT=local
    depends_on:
      - mongodb
      - redis

  frontend:
    build: ./frontend
    ports:
      - "3000:80"
    depends_on:
      - backend

  mongodb:
    image: mongo:7.0
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=password
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db

  redis:
    image: redis:7.2-alpine
    command: redis-server --requirepass password
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  mongodb_data:
  redis_data:
```

---

## Environment Variables Reference

### Backend

```
MONGODB_URL         — full MongoDB connection string including credentials
MONGODB_DB          — database name, default: space_explorer
REDIS_URL           — full Redis connection string including password
CACHE_TTL           — Redis cache TTL in seconds, default: 60
NASA_API_KEY        — NASA API key, default: DEMO_KEY
WARMUP_SECONDS      — seconds to wait before marking ready, default: 30
ENVIRONMENT         — dev, staging, or prod
APP_VERSION         — injected by Jenkins as git commit SHA
```

### Frontend

```
VITE_API_URL        — not needed since Nginx proxies /api to backend
```

---

## Git Ignore

```
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
.terraform.lock.hcl
*.tfvars
!*.tfvars.example

# Python
__pycache__/
*.pyc
.env
venv/
.pytest_cache/

# Node
node_modules/
dist/
.env.local

# Misc
*.pem
.DS_Store
```

---

## README Requirements

The README must include:

1. Architecture diagram showing all four tiers and how they connect
2. CI/CD pipeline flow diagram showing Jenkins stages
3. GitOps flow diagram showing how ArgoCD syncs
4. Prerequisites — AWS account, Terraform, kubectl, Helm, Docker
5. Step by step setup instructions:
   - Clone repo
   - Configure AWS credentials
   - Create S3 bucket and DynamoDB table for Terraform state
   - Run Terraform for desired environment
   - Configure kubectl to point to new EKS cluster
   - Apply ArgoCD root app
   - Configure Jenkins with credentials
   - Push code to trigger first pipeline run
6. How to add a new environment
7. How secrets rotation works with External Secrets Operator
8. Local development with Docker Compose instructions

---

## Important Notes for Claude Code

- Never hardcode secrets or credentials anywhere in the code
- All sensitive values must come from environment variables
- Terraform variables for passwords must be marked sensitive = true
- Never commit terraform.tfvars files — only commit terraform.tfvars.example with placeholder values
- The .gitignore must exclude *.tfvars, *.pem, .env files
- All Docker images must run as non-root users
- All Kubernetes deployments must have resource requests and limits defined
- All deployments must have liveness and readiness probes configured
- HPA must be enabled for backend in all environments
- MongoDB and Redis use the credentials synced by External Secrets Operator — never hardcode passwords in Helm values
- The Jenkins pipeline must use dynamic pod agents — no static agents
- ArgoCD prod applications must have automated sync disabled — manual sync only for production
- Use path based triggers in Jenkinsfile so only the changed service pipeline runs
- Image tags must use git commit SHA not latest for traceability
- The frontend Nginx must proxy /api requests to backend — single ingress for both services