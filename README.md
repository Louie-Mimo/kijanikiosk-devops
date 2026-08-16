# KijaniKiosk DevOps Capstone

KijaniKiosk is a DevOps capstone project demonstrating an end-to-end,
infrastructure-first delivery workflow for a containerized payments service.

The project combines Git and GitHub collaboration, Docker containerization,
Kubernetes, Terraform, Ansible, Jenkins CI/CD, security scanning,
staging-first deployment, production approval gates, log-based error-rate
monitoring, and AWS S3/Lambda serverless integration.

The capstone follows a Track A infrastructure-first implementation.

---

## Project Objectives

The delivery flow is:

```text
Developer Change
       |
       v
GitHub
       |
       v
Jenkins CI
       |
       v
Infrastructure Validation
       |
       v
Ansible Staging Configuration
       |
       v
Kubernetes Staging Deployment
       |
       v
Smoke Test
       |
       v
Error-Rate Gate
       |
       v
Human Production Approval
       |
       v
Kubernetes Production Deployment
```

The staging-only serverless receipt flow is:

```text
Payment Request
       |
       v
kk-payments
       |
       v
AWS S3 incoming/
       |
       v
Receipt Processor Lambda
       |
       v
S3 processed/
       |
       v
Notifier Lambda
       |
       v
S3 notifications/
```

---

# Architecture

Detailed architecture artifacts:

```text
docs/architecture.mmd
docs/architecture.svg
docs/architecture.png
```

Capstone scope:

```text
docs/capstone-scope.md
```

---

# Technology Stack

| Area | Technology |
|---|---|
| Source Control | Git, GitHub |
| CI/CD | Jenkins |
| Containers | Docker |
| Container Registry | GitHub Container Registry |
| Orchestration | Kubernetes / Minikube |
| Infrastructure as Code | Terraform |
| Configuration Management | Ansible |
| Application Runtime | Node.js 20 |
| Monitoring | Log-based HTTP error-rate monitor |
| Cloud Storage | AWS S3 |
| Serverless Processing | AWS Lambda |
| Cloud Logging | Amazon CloudWatch |
| Security | npm audit, Kubernetes Secrets, IAM least privilege |

---

# Repository Structure

```text
kijanikiosk-devops/
├── Jenkinsfile
├── README.md
├── ansible/
├── deployment-pipeline/
│   └── containers/
├── docs/
├── k8s/
├── monitoring/
├── serverless/
│   ├── README.md
│   ├── functions/
│   ├── terraform/
│   └── verify-receipt-chain.sh
└── terraform/
```

Historical weekly coursework is also retained in the repository.

---

# Environments

## Staging

Namespace:

```text
kijani-staging
```

Important settings:

```text
NODE_ENV=staging
DB_HOST=kk-postgres-staging
AWS_REGION=eu-north-1
RECEIPTS_BUCKET=kk-payments-receipts-staging
```

Staging is used for deployment validation, smoke testing, monitoring,
receipt-chain integration, and pre-production verification.

## Production

Namespace:

```text
kijani-project
```

Important settings:

```text
NODE_ENV=production
DB_HOST=kk-postgres
```

Production does not currently configure:

```text
RECEIPTS_BUCKET
```

Receipt publishing is therefore disabled in production.

The same application image and Kubernetes Deployment manifest can be
promoted from staging to production while ConfigMaps and Secrets provide
environment-specific behavior.

---

# Kubernetes Deployment

Primary payment service:

```text
kk-payments
```

Current capstone image:

```text
ghcr.io/louie-mimo/kk-payments:v1.2.0
```

Replica count:

```text
3
```

Application port:

```text
3001
```

Health endpoint:

```text
GET /health
```

Payment endpoint:

```text
GET /payment?amount=<amount>
```

The same Deployment manifest is applied to both environments:

```bash
kubectl apply -n kijani-staging -f k8s/kk-payments-deployment.yaml
kubectl apply -n kijani-project -f k8s/kk-payments-deployment.yaml
```

---

# Terraform

The main Track A Terraform configuration is located under:

```text
terraform/
```

It provisions the staging namespace:

```text
kijani-staging
```

Validation example:

```bash
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
terraform -chdir=terraform plan
```

The AWS receipt-chain infrastructure is defined separately under:

```text
serverless/terraform/
```

This configuration manages the staging S3 receipt bucket, Lambda functions,
S3 event notification, IAM roles, and the staging receipt-writer IAM identity.

Generated Terraform artifacts are excluded from Git.

---

# Ansible

Ansible configures the staging environment after Terraform provisioning.

Configuration:

```text
ansible/group_vars/all.yml
```

Playbook:

```text
ansible/playbook.yml
```

Important managed values:

```text
NODE_ENV=staging
DB_HOST=kk-postgres-staging
AWS_REGION=eu-north-1
RECEIPTS_BUCKET=kk-payments-receipts-staging
```

Run:

```bash
ansible-playbook   -i ansible/inventory/hosts.yml   ansible/playbook.yml
```

An idempotent run should complete with `failed=0` and avoid unnecessary
changes on subsequent executions.

---

# Jenkins CI/CD Pipeline

The pipeline is defined in:

```text
Jenkinsfile
```

The production branch is:

```text
master
```

## Exact Pipeline Structure

The Jenkinsfile defines these stages:

```text
CI
 |
 +--> Lint
 |
 +--> Build
 |
 +--> Verify
 |     |
 |     +--> Unit & Integration Tests
 |     |
 |     +--> Security Audit
 |
 +--> Archive
 |
 +--> Publish to Nexus
      (parameter-controlled / optional)

        |
        v

Validate Infrastructure
        |
        v
Prepare Ansible Runtime
        |
        v
Configure Staging
        |
        v
Verify Staging Prerequisites
        |
        v
Deploy Staging
        |
        v
Staging Smoke Test
        |
        v
Staging Error Rate Check
        |
        v
Production Approval
        |
        v
Verify Production Prerequisites
        |
        v
Deploy Production
```

The infrastructure and deployment stages after CI are restricted to the
`master` branch.

## CI

### Lint

Executes the configured lint or syntax-validation process.

### Build

Builds the application before deployment activities begin.

### Verify

Runs in parallel:

```text
Verify
├── Unit & Integration Tests
└── Security Audit
```

The security gate enforces:

```bash
npm audit --audit-level=high
```

High-severity dependency vulnerabilities therefore fail CI rather than being
silently ignored.

### Archive

Archives build and verification artifacts as pipeline evidence.

### Publish to Nexus

This stage exists but is controlled by:

```text
PUBLISH_TO_NEXUS
```

The normal capstone deployment uses:

```text
PUBLISH_TO_NEXUS=false
```

so Nexus publication is optional.

## Validate Infrastructure

On `master`, Jenkins validates the Terraform infrastructure configuration
before deployment continues.

## Prepare Ansible Runtime

Jenkins prepares the Python and Ansible runtime required for staging
configuration.

## Configure Staging

Ansible configures the staging `kk-payments-config` ConfigMap with values
including:

```text
NODE_ENV=staging
DB_HOST=kk-postgres-staging
AWS_REGION=eu-north-1
RECEIPTS_BUCKET=kk-payments-receipts-staging
```

## Verify Staging Prerequisites

Jenkins checks that the required staging namespace, configuration, and Secrets
exist before application deployment.

The staging database host is explicitly verified as:

```text
kk-postgres-staging
```

## Deploy Staging

The Kubernetes Deployment manifest is applied to:

```text
kijani-staging
```

Jenkins waits for the rollout to succeed.

## Staging Smoke Test

Jenkins performs a live request against:

```text
/health
```

Production promotion cannot continue if this stage fails.

## Staging Error Rate Check

The log-based monitoring gate enforces:

```text
ERROR_RATE > 5% => ALERT
```

A monitoring failure blocks production approval.

## Production Approval

After staging deployment, smoke testing, and monitoring have succeeded,
Jenkins pauses at a manual approval gate.

A human must explicitly approve promotion to production. The stage also has a
timeout to prevent an unattended pipeline from remaining indefinitely eligible
for production deployment.

## Verify Production Prerequisites

Production configuration is checked before deployment.

The production database host is explicitly verified as:

```text
kk-postgres
```

## Deploy Production

The same Kubernetes Deployment manifest is applied to:

```text
kijani-project
```

The final capstone pipeline successfully promoted:

```text
ghcr.io/louie-mimo/kk-payments:v1.2.0
```

with:

```text
3 available replicas
```

## Production Promotion Controls

Production is unreachable until all of these conditions succeed:

1. CI
2. Security Audit
3. Terraform validation
4. Ansible staging configuration
5. Staging prerequisite checks
6. Staging deployment
7. Staging smoke test
8. Staging error-rate check
9. Human production approval
10. Production prerequisite checks

---

# CI Runtime

The CI environment uses Node.js 20.

Application validation includes:

```bash
npm ci
npm test
npm run build
npm audit --audit-level=high
```

Final receipt-chain application validation:

```text
Tests: 3 passed
npm audit: 0 vulnerabilities
```

---

# Security

Implemented controls include:

- npm dependency auditing
- remediation of high-severity dependency vulnerabilities
- Kubernetes Secrets for sensitive configuration
- no credentials stored in source control
- `.gitignore` protection for generated Terraform artifacts
- private S3 receipt bucket
- S3 public-access blocking
- S3 server-side encryption
- S3 versioning
- dedicated AWS receipt-writer identity
- least-privilege IAM permissions
- staging/production environment separation
- non-root application container user

Generated files excluded from Git include:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
.build/
```

---

# Error-Rate Monitoring

The monitoring implementation is under:

```text
monitoring/
```

The staging monitor performs 20 live HTTP requests against `/health`.

Error rate:

```text
error requests / total requests * 100
```

Threshold:

```text
ERROR_RATE > 5% => ALERT
```

Boundary behavior:

```text
5.00%  => HEALTHY
10.00% => ALERT
```

Example healthy result:

```text
TOTAL_REQUESTS=20
ERROR_REQUESTS=0
ERROR_RATE=0.00%
THRESHOLD=5.00%
STATUS=HEALTHY
```

Run the controlled test:

```bash
./monitoring/test-error-rate-monitor.sh
```

Run the live staging monitor:

```bash
./monitoring/check-staging-error-rate.sh
```

---

# AWS Receipt Chain

Detailed serverless documentation:

```text
serverless/README.md
```

Flow:

```text
GET /payment?amount=2500
        |
        v
kk-payments
        |
        | receipt_published
        v
S3 incoming/
        |
        | ObjectCreated
        v
Receipt Processor Lambda
        |
        | processingStatus=PROCESSED
        v
S3 processed/
        |
        v
Notifier Lambda
        |
        | notificationStatus=SENT
        v
S3 notifications/
```

A successful staging payment returns a receipt object similar to:

```json
{
  "status": "SUCCESS",
  "amount": 2500,
  "receipt": {
    "status": "PUBLISHED",
    "receiptId": "rcpt-...",
    "bucket": "kk-payments-receipts-staging",
    "key": "incoming/rcpt-....json"
  }
}
```

The same receipt ID is preserved across:

```text
incoming/
processed/
notifications/
```

Verify a receipt:

```bash
./serverless/verify-receipt-chain.sh <receipt-id>
```

A successful run ends with:

```text
PASS: receipt chain completed for <receipt-id>
```

---

# Container Build

Build:

```bash
docker build   -f deployment-pipeline/containers/Dockerfile.production   -t ghcr.io/louie-mimo/kk-payments:v1.2.0   deployment-pipeline/containers
```

Verify Node.js:

```bash
docker run   --rm   --entrypoint node   ghcr.io/louie-mimo/kk-payments:v1.2.0   --version
```

Push:

```bash
docker push ghcr.io/louie-mimo/kk-payments:v1.2.0
```

---

# Staging Verification

```bash
kubectl get deployment kk-payments -n kijani-staging
kubectl get pods -n kijani-staging -l app=kk-payments
```

Verify the image:

```bash
kubectl get deployment kk-payments   -n kijani-staging   -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Expected:

```text
ghcr.io/louie-mimo/kk-payments:v1.2.0
```

Expected staging configuration:

```text
NODE_ENV=staging
DB_HOST=kk-postgres-staging
AWS_REGION=eu-north-1
RECEIPTS_BUCKET=kk-payments-receipts-staging
```

---

# Production Verification

```bash
kubectl get deployment kk-payments -n kijani-project
```

Verify image:

```bash
kubectl get deployment kk-payments   -n kijani-project   -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Expected:

```text
ghcr.io/louie-mimo/kk-payments:v1.2.0
```

Expected production state:

```text
available=3
NODE_ENV=production
DB_HOST=kk-postgres
RECEIPTS_BUCKET=
```

The empty production receipt bucket is intentional and keeps the receipt
integration staging-only.

---

# Failure and Recovery

The project demonstrates controlled failure and recovery, including:

- invalid image deployment
- Kubernetes rollout failure
- rollout history inspection
- rollback to a known-good image
- staging gate failure
- production approval timeout
- dependency vulnerability detection
- remediation through GitHub Issue and Pull Request

A failed staging validation prevents production promotion.

---

# Git Workflow

Development uses feature branches and pull requests.

Examples include:

```text
feature/error-rate-monitoring
feature/receipt-chain-integration
chore/remove-tracked-terraform-plans
```

Conventional commit styles include:

```text
feat(...)
fix(...)
docs(...)
infra(...)
chore(...)
security(...)
```

---

# Prerequisites

Recommended tools:

```text
Git
Docker
kubectl
Minikube
Terraform
Ansible
Python 3
AWS CLI
GitHub CLI
Jenkins
```

Valid AWS credentials are required for receipt-chain administration.

Sensitive credentials must never be committed to the repository.

---

# Quick Verification Checklist

Repository:

```bash
git status
```

Terraform:

```bash
terraform -chdir=terraform validate
```

Ansible:

```bash
ansible-playbook   -i ansible/inventory/hosts.yml   ansible/playbook.yml   --syntax-check
```

Monitoring:

```bash
./monitoring/test-error-rate-monitor.sh
```

Staging:

```bash
kubectl get deployments,pods -n kijani-staging
```

Production:

```bash
kubectl get deployments,pods -n kijani-project
```

Receipt chain:

```bash
./serverless/verify-receipt-chain.sh <receipt-id>
```

---

# Known Limitations

## Receipt Integration

Receipt publishing is currently enabled only in staging.

Production would require a separate production S3 bucket, production IAM
permissions, production credential management, and deliberate production
configuration.

## Notification Delivery

The notifier demonstrates event processing by creating a notification record
in S3. It does not currently send external SMS, email, or push notifications.

## AWS Authentication

The local Minikube staging workload currently uses a dedicated AWS access key
stored in a Kubernetes Secret.

A managed Kubernetes platform should use workload identity, such as IAM Roles
for Service Accounts or an equivalent mechanism.

## Serverless Terraform State

The AWS serverless Terraform state is local and intentionally excluded from
version control.

A production implementation should use a secure remote Terraform backend with
state locking and controlled access.

## Local Infrastructure

The capstone primarily runs on local Minikube and Jenkins rather than a
managed production Kubernetes platform.

---

# Evidence

Capstone evidence includes:

- architecture diagram
- scope document
- Terraform validation
- Ansible staging configuration
- Kubernetes deployment verification
- Jenkins staging-first pipeline
- production approval screenshots
- monitoring threshold proof
- security remediation evidence
- receipt-chain payment response
- S3 receipt objects
- Kubernetes receipt logs
- Lambda CloudWatch logs
- successful production deployment

---

# Capstone Deliverables

The final submission includes:

- capstone scope
- architecture diagram
- GitHub repository
- pipeline demonstration evidence
- peer feedback log
- AI governance log
- presentation slides
- reflection document
- tagged final release

---

# Release

The final audited capstone release will be tagged:

```text
v1.0.0
```

The tag should only be created after all technical, documentation,
governance, and submission deliverables pass the final audit.

---

# Author

Louisza Amimo - KijaniKiosk DevOps Capstone

Track A — Infrastructure-First Delivery
