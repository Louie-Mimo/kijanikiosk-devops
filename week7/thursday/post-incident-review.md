# Post-Incident Review — Week 5 Production Configuration Incident

## 1. Incident Summary

On Monday morning during Nia's investor walkthrough, Amina ran `make configure ENV=production`. The command allowed a production configuration path to be selected manually and applied changes during a live demonstration. The incident was detected immediately, changes were stopped, the previous known-good configuration was restored, and service operation was verified. No intentional malicious action occurred; the incident exposed weaknesses in deployment guardrails.

## 2. Impact

Production configuration was unintentionally targeted during an investor demonstration. This created a risk of service disruption and configuration drift. The walkthrough was interrupted while the team investigated and recovered the environment. The incident demonstrated that production selection depended too heavily on a manually supplied environment value.

## 3. Timeline

> Times are reconstructed from the Week 5 incident sequence.

| Time | Event |
|------|-------|
| 09:02 | Amina opens the terminal during Nia's investor walkthrough. |
| 09:03 | Amina prepares to demonstrate the configuration workflow. |
| 09:04 | `make configure ENV=production` is executed. |
| 09:04 | The Makefile accepts `production` without an environment-protection check. |
| 09:05 | Production-targeted configuration begins. |
| 09:06 | Unexpected production activity is noticed during the walkthrough. |
| 09:07 | Tendo asks Amina to stop further configuration changes. |
| 09:09 | The team identifies the manually supplied `ENV=production` value as the trigger. |
| 09:12 | The previous known-good configuration is reapplied. |
| 09:15 | Verification checks confirm the service and configuration are healthy. |
| 09:17 | Nia confirms recovery and the investor walkthrough resumes. |

## 4. Root Cause — Five Whys

**Why 1:** Why was production targeted?  
Because Amina executed `make configure ENV=production`.

**Why 2:** Why could a local command select production?  
Because the `Makefile` accepted an operator-supplied `ENV` value and passed it to the configuration process.

**Why 3:** Why was the supplied environment not rejected?  
Because the Week 5 deployment controls did not make environment selection an immutable pipeline decision.

**Why 4:** Why did the pipeline rely on manual environment input?  
Because environment safety was implemented as an operator convention rather than an enforced deployment policy.

**Why 5:** Why could one command reach a sensitive environment during a demonstration?  
Because production protection lacked defence in depth: branch-derived environment selection, protected GitHub environments, and approval gates were not all enforced.

**Root cause:** production environment selection was controllable from a local command instead of being derived and enforced by trusted pipeline context.

## 5. Contributing Factors and Prevention

| Contributing factor | Prevention mechanism |
|---|---|
| Manual `ENV` selection allowed production targeting. | Update the **`Makefile`** so `make configure` does not accept a production environment override. |
| Environment selection was not centrally enforced. | The **`set-environment` job in `.github/workflows/deploy.yml`** derives the environment from `github.ref_name` and removes reliance on the user-supplied `ENV` parameter. |
| Production changes could proceed without an explicit deployment gate. | Protect the production deployment used by the **`configure` job in `.github/workflows/deploy.yml`** with a GitHub Environment and required approval. |
| Recovery depended on manual observation. | The **`verify` job in `.github/workflows/deploy.yml`** must validate the resulting environment before subsequent deployment stages continue. |

## 6. Action Items

| Action | Owner | Target |
|--------|-------|--------|
| Remove manual production environment selection from the `Makefile` and require pipeline-derived environment values. | Amina | Week 5 |
| Enforce branch-based environment selection and production approval controls in `.github/workflows/deploy.yml`. | Tendo | Week 5 |
| Add a pre-demo checklist requiring verification of target environment and pipeline state before investor demonstrations. | Nia | Week 6 |
