# AI Governance Log — KijaniKiosk DevOps Capstone

This log records material uses of generative AI during the KijaniKiosk DevOps capstone. AI output was treated as advisory: commands, configuration, code, and documentation were reviewed, tested, and changed before being accepted into the project.

---

## Entry 1

**Date:** 2026-08-10  
**Tool:** ChatGPT  
**Task:** Kubernetes deployment and service configuration review  
**Context/Prompt:** Asked for guidance while building the `kk-payments` Kubernetes Deployment and Service, including replicas, ports, probes, resources, namespace usage, and validation commands.  
**Output:** Suggested Kubernetes YAML structure and a command-by-command validation workflow using `kubectl`, rollout status, pod inspection, service checks, and health requests.  
**What got right:** The guidance helped establish a repeatable Kubernetes deployment workflow and supported the final three-replica `kk-payments` deployment with health verification.  
**What got wrong:** Some early guidance was broader than the exact repository state and required checking against the manifests already present in the project before applying it.  
**What changed before applying:** Existing YAML was inspected first, only the required fields were changed, and every deployment change was verified against the live Minikube cluster before being retained.

---

## Entry 2

**Date:** 2026-08-10  
**Tool:** ChatGPT  
**Task:** Kubernetes rollback demonstration planning  
**Context/Prompt:** Asked how to demonstrate deployment failure and recovery for the capstone using an intentionally invalid `kk-payments` image and Kubernetes rollout history.  
**Output:** Proposed a controlled bad-image rollout, rollout-status inspection, revision-history evidence, and rollback to the known-good image.  
**What got right:** The approach produced clear failure-and-recovery evidence and demonstrated Kubernetes rollback behavior without changing application logic.  
**What got wrong:** The initial sequence needed extra care to avoid leaving the bad image as the final desired state after the demonstration.  
**What changed before applying:** The bad image was used only as a controlled temporary failure, rollout history was checked, and the deployment was explicitly restored and verified on the known-good image.

---

## Entry 3

**Date:** 2026-08-14  
**Tool:** ChatGPT  
**Task:** Terraform and Ansible staging-environment design  
**Context/Prompt:** Asked how to satisfy the Track A requirement that `kijani-staging` be provisioned by Terraform and configured by Ansible while remaining isolated from production.  
**Output:** Proposed a Terraform-managed Kubernetes namespace and an Ansible-managed staging ConfigMap with assertions for environment-specific values such as `DB_HOST`.  
**What got right:** The split between Terraform provisioning and Ansible configuration matched the capstone requirement and provided clear evidence of environment separation.  
**What got wrong:** Early suggestions did not yet include the later AWS receipt-chain settings because that integration had not been implemented at that point.  
**What changed before applying:** The configuration was later extended to include `RECEIPTS_BUCKET` and `AWS_REGION`, and assertions were added so the playbook verifies those exact staging values.

---

## Entry 4

**Date:** 2026-08-14  
**Tool:** ChatGPT  
**Task:** Jenkins staging-first CI/CD pipeline design  
**Context/Prompt:** Asked for a Jenkins flow that automatically deploys `master` to staging, smoke-tests it, runs validation gates, and requires manual approval before production.  
**Output:** Suggested a declarative pipeline with CI, infrastructure validation, Ansible configuration, staging deployment, smoke testing, a production approval gate, and production deployment.  
**What got right:** The resulting design enforced staging-first promotion and ensured production was unreachable until the required validation and approval steps succeeded.  
**What got wrong:** Some documentation initially paraphrased stage names rather than matching the exact `Jenkinsfile` stage names.  
**What changed before applying:** The final README was audited against the actual `Jenkinsfile` and updated to use exact names such as `Prepare Ansible Runtime`, `Verify Staging Prerequisites`, `Staging Error Rate Check`, and `Verify Production Prerequisites`.

---

## Entry 5

**Date:** 2026-08-15  
**Tool:** ChatGPT  
**Task:** Dependency security-gate remediation  
**Context/Prompt:** Asked for help making `npm audit --audit-level=high` a real Jenkins gate after high-severity dependency findings were identified.  
**Output:** Recommended removing the non-blocking audit behavior, updating the lockfile with `npm audit fix --package-lock-only`, rerunning tests, and documenting the remediation through GitHub Issue and Pull Request evidence.  
**What got right:** The final pipeline enforced the security audit and the validated package set reported zero vulnerabilities while tests still passed.  
**What got wrong:** Updating the dependency lockfile later during receipt-chain work temporarily reintroduced audit findings that had to be remediated again.  
**What changed before applying:** The lockfile was re-audited after the AWS SDK dependency change, `npm audit fix --package-lock-only` was rerun, and the final Node 20 validation confirmed `found 0 vulnerabilities`.

---

## Entry 6

**Date:** 2026-08-15  
**Tool:** ChatGPT  
**Task:** Log-based staging error-rate monitoring design  
**Context/Prompt:** Asked how to satisfy the Track A monitoring requirement using a lightweight log-based error-rate signal and integrate it into Jenkins before production approval.  
**Output:** Proposed a Python error-rate calculator, a shell wrapper that performs live staging health requests, a controlled threshold test, and a Jenkins stage that fails when the rate is greater than 5 percent.  
**What got right:** The implementation proved the boundary semantics (`5.00% = HEALTHY`, `10.00% = ALERT`) and the final Jenkins run reported `0.00%` before production approval.  
**What got wrong:** The monitoring approach is intentionally lightweight and does not provide long-term time-series storage, dashboards, or distributed observability.  
**What changed before applying:** The solution was explicitly scoped and documented as a capstone log-based monitor, test fixtures were added for the threshold boundary, and Jenkins archived the monitoring evidence.

---

## Entry 7

**Date:** 2026-08-16  
**Tool:** ChatGPT  
**Task:** AWS serverless receipt-chain architecture and Terraform implementation  
**Context/Prompt:** Asked how to integrate the Week 10 receipt requirement so a successful staging payment writes a receipt to S3 and triggers processing and notification steps.  
**Output:** Proposed an S3 `incoming/` prefix, S3 ObjectCreated notification, receipt-processor Lambda, `processed/` output, asynchronous notifier Lambda, `notifications/` output, and least-privilege IAM managed through Terraform.  
**What got right:** The deployed chain worked end to end and preserved the same receipt ID across incoming, processed, and notification objects, with matching CloudWatch evidence.  
**What got wrong:** The first implementation path required additional decisions around how application credentials would be supplied because Terraform intentionally did not create an IAM access key.  
**What changed before applying:** A dedicated staging writer access key was created outside Terraform, stored only in a Kubernetes Secret, temporary credential files were deleted, and the Terraform code retained only the IAM user and least-privilege policy.

---

## Entry 8

**Date:** 2026-08-16  
**Tool:** ChatGPT  
**Task:** `kk-payments` receipt-publishing integration and runtime upgrade  
**Context/Prompt:** Asked to connect the existing payment endpoint to the AWS receipt chain while keeping the same Deployment manifest usable in staging and production.  
**Output:** Suggested a `receipt-writer.js` module using the AWS SDK, receipt publication after successful payment, a disabled mode when `RECEIPTS_BUCKET` is absent, Node.js 20 container/runtime updates, and unit tests using an injected/mock S3 client.  
**What got right:** Staging successfully published a real receipt while production remained safe with `RECEIPTS_BUCKET` unset; tests passed and the same v1.2.0 image was promoted to production.  
**What got wrong:** The AWS SDK version selected required Node.js 20, while the existing project runtime was Node.js 18, so the first integration could not simply be added without a runtime change.  
**What changed before applying:** The production Dockerfile and Jenkins CI image were upgraded to Node.js 20, the image was rebuilt and tested, and the final container reported Node 20 with zero audit vulnerabilities.

---

## Entry 9

**Date:** 2026-08-16  
**Tool:** ChatGPT  
**Task:** Receipt-chain verification and environment-configuration troubleshooting  
**Context/Prompt:** Asked for help after `AWS_REGION` appeared blank inside a restarted staging pod even though the receipt feature itself was working.  
**Output:** Suggested comparing the Ansible source configuration, Ansible assertions, live Kubernetes ConfigMap, and pod environment, then verifying all currently running pods rather than relying on a single pod selection.  
**What got right:** The checks confirmed both the Ansible source and live ConfigMap contained `AWS_REGION=eu-north-1`, narrowing the issue to pod timing/selection rather than source configuration.  
**What got wrong:** An earlier verification command selected only one pod and could therefore report an old pod during rollout, which made the configuration appear incorrect.  
**What changed before applying:** Verification was changed to iterate across all Running `kk-payments` pods, and the reusable receipt-chain script was used to independently confirm `incoming/`, `processed/`, and `notifications/` objects.

---

## Entry 10

**Date:** 2026-08-16  
**Tool:** ChatGPT  
**Task:** Repository secret and generated-artifact audit  
**Context/Prompt:** Asked for a final pre-commit audit to ensure AWS/GitHub credentials, Terraform state, build artifacts, and saved Terraform plans were not accidentally committed.  
**Output:** Suggested working-tree and tracked-file credential pattern scans, generated Terraform artifact checks, `git diff --check`, and controlled staging of files instead of `git add .`.  
**What got right:** No obvious credentials were found in the working tree or tracked source, and the receipt-chain commits excluded Terraform state, plans, `.terraform/`, and Lambda build output.  
**What got wrong:** The repository-wide audit discovered two older Week 4 `.tfplan` files that were already tracked, meaning the first check could not report a completely clean repository.  
**What changed before applying:** The historical plan files were checked without printing their contents, removed through a dedicated cleanup branch and Pull Request, and repository-wide `.tfplan` hygiene was verified before final documentation work.

---

## Entry 11

**Date:** 2026-08-16  
**Tool:** ChatGPT  
**Task:** Serverless documentation and reusable verification script  
**Context/Prompt:** Asked for documentation explaining the receipt-chain architecture, Terraform resources, security controls, deployment process, and proof of an end-to-end receipt.  
**Output:** Produced `serverless/README.md` content and a `verify-receipt-chain.sh` workflow that checks matching receipt objects across the three S3 prefixes.  
**What got right:** The verification script successfully proved the actual receipt `rcpt-1786890391408-07143259` existed in incoming, processed, and notification stages with `PROCESSED` and `SENT` status values.  
**What got wrong:** An earlier README heredoc response was incomplete, so the first documentation insertion could have truncated the intended document if accepted without checking.  
**What changed before applying:** The README was regenerated completely, file length and content were checked, and the verification script was syntax-tested and executed successfully before being committed.

---

## Entry 12

**Date:** 2026-08-16  
**Tool:** ChatGPT  
**Task:** Final root README drafting and factual audit  
**Context/Prompt:** Asked for a capstone root README covering architecture, prerequisites, setup, pipeline, verification, monitoring, security, receipt processing, limitations, and release information.  
**Output:** Drafted a consolidated root README and then provided a revised downloadable version after comparing its Jenkins section with the actual stage names in `Jenkinsfile`.  
**What got right:** The final structure provides a single reviewer entry point for Terraform, Ansible, Kubernetes, Jenkins, monitoring, AWS receipt processing, validation commands, limitations, and final release expectations.  
**What got wrong:** The first README draft described some Jenkins stages using conceptual names such as `Terraform Validation` and omitted `Prepare Ansible Runtime`, so it was not yet an exact representation of the Jenkinsfile.  
**What changed before applying:** The actual stage names were extracted with `grep`, the documentation was rewritten to reflect the exact pipeline structure, and Markdown fences and whitespace were validated before staging.

---

## Governance Summary

AI was used as an engineering assistant for design suggestions, command drafting,
code generation, troubleshooting, documentation, and audit checklists. AI output
was not treated as authoritative or applied blindly. Material changes were
validated through source inspection, automated tests, `npm audit`, Terraform
validation, Ansible syntax/assertion checks, Kubernetes rollout and configuration
checks, Jenkins execution, AWS/S3 verification, Git diff review, and credential
scanning before being accepted into the capstone.
