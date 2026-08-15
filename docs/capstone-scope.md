# Capstone Scope Document

## Problem Statement

KijaniKiosk currently has a production-approaching Kubernetes deployment, but
application releases are deployed without an isolated staging environment and
a staging-first promotion workflow. The current system therefore cannot prove
that a release is healthy under environment-specific configuration before it
is promoted to the production namespace. The capstone will close this gap by
introducing a reproducible staging environment, automated staging deployment
and validation, controlled production promotion, operational monitoring, and
receipt-event integration.

## Track

**Track A — Infrastructure-First**

## What I Will Build

1. **Terraform-managed staging environment** — Terraform will provision the
   `kijani-staging` Kubernetes namespace so the staging environment can be
   reproduced from Infrastructure as Code rather than created manually.

2. **Ansible-managed staging configuration** — Ansible will configure the
   staging environment with an environment-specific `kk-payments-config`
   ConfigMap, including a staging `DB_HOST` that is different from production.

3. **Staging-first Jenkins delivery pipeline** — Jenkins will deploy
   `kk-payments` to `kijani-staging`, wait for the Kubernetes rollout, execute
   an HTTP health smoke test, and expose the production approval gate only
   after the staging validation succeeds.

4. **Operational monitoring** — A repository-managed log-based error-rate
   monitor will analyse structured `kk-payments` logs and report whether the
   service exceeds the 5% error-rate threshold used by the KijaniKiosk SLO.

5. **Receipt-chain integration** — The staging `kk-payments` configuration will
   use the `kk-payments-receipts-staging` bucket so payment receipt events can
   enter the Week 10 serverless receipt-processing chain.

## What Is Out of Scope

- **Managed production Kubernetes service** — The capstone will use the
  existing local Minikube environment because the engineering focus is
  reproducible infrastructure and controlled application delivery rather than
  migration to EKS, AKS, or GKE.

- **Full Prometheus and Grafana platform** — The project will use the permitted
  structured-log error-rate monitoring option, avoiding installation of a
  monitoring platform solely for demonstration purposes.

- **Production TLS and public Internet exposure** — TLS termination, production
  DNS, WAF controls, and externally trusted certificates remain production
  readiness improvements rather than capstone implementation scope.

- **Production-grade database deployment** — The project will demonstrate
  environment-specific database configuration but will not provision a
  production PostgreSQL HA cluster.

## Success Criteria

1. Running the documented Terraform and Ansible workflow creates
   `kijani-staging` and results in a staging `kk-payments-config` whose
   `DB_HOST` differs from the production value.

2. A Jenkins deployment successfully deploys `kk-payments` to staging, waits
   for `kubectl rollout status`, receives HTTP 200 from the staging health
   smoke test, and only then presents the production approval gate.

3. A staging payment can generate a receipt event for
   `kk-payments-receipts-staging`, while the repository monitoring process can
   calculate and report the `kk-payments` error rate against the 5% threshold.

## Architecture Diagram

The capstone architecture diagram will be stored at:

`docs/architecture.png`

It will show the GitHub-to-Jenkins delivery path, Terraform and Ansible
infrastructure/configuration responsibilities, staging and production
Kubernetes namespaces, the smoke-test and approval flow, receipt-event
integration, and the structured-log monitoring path.
