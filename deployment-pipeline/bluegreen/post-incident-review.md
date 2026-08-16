# KijaniKiosk Post-Incident Review

## 1. Incident Summary

During an investor demonstration, the deployment pipeline targeted the wrong environment and caused staging to become unavailable for **48 seconds**. Service was restored during the demonstration, but the incident exposed a deployment-safety gap: the pipeline could act on an unintended environment without an enforced validation step preventing the change.

This review focuses on the system and process conditions that allowed the incident to happen and on concrete changes that reduce the chance of recurrence.

---

## 2. Timeline

> **Timeline note:** Exact wall-clock timestamps for the earlier incident were not retained in the evidence available for this review. To avoid inventing precision, the timeline uses incident-relative timestamps. The known measured fact is that staging unavailability lasted **48 seconds**. Events whose exact offset cannot be reconstructed are marked as estimated.

| Relative timestamp | Event | Confidence / basis |
|---|---|---|
| **T-~1 min (estimated)** | Investor walkthrough was in progress and the team prepared to demonstrate the deployment workflow. | Based on the incident narrative stating that the failure happened during an investor demonstration. Exact clock time is unavailable. |
| **T+00:00 (reconstructed anchor)** | The deployment action affecting staging began. The pipeline was operating against the wrong environment. | This is used as the start of the incident window because the precise original clock time was not retained. |
| **T+~00:00 to T+~00:10 (estimated)** | The unintended environment change began affecting the staging service and requests started failing. | Exact onset within the deployment action is not available in retained evidence. |
| **T+~00:10 to T+~00:30 (estimated)** | The team detected that the demonstration environment was unavailable and identified that the deployment had targeted the wrong environment. | The narrative confirms the wrong-environment condition but does not provide the original detection timestamp. |
| **T+~00:30 to T+00:48 (estimated)** | The team corrected the deployment state and restored the expected environment. | The recovery action is reconstructed from the known total staging-unavailability duration. |
| **T+00:48 (confirmed duration boundary)** | Normal staging service was restored. | The assignment records **48 seconds of staging unavailability**. |

The most important fact is not the exact missing wall-clock time; it is that an unintended deployment target was able to affect the demonstration environment and cause 48 seconds of unavailability.

---

## 3. Root Cause

### Immediate technical cause

The pipeline was able to run against the **wrong environment** during the investor demonstration.

The configuration gap was that the deployment process did not enforce a sufficiently strong validation between the intended deployment target and the environment the pipeline was about to modify. An environment selection could therefore reach the deployment step without an independent safety check proving that it matched the intended target.

### Five Whys Analysis

**Why 1: Why did staging become unavailable during the investor demonstration?**

Because the deployment pipeline executed against an environment that was not the intended target, changing the state of the environment being used for the demonstration.

**Why 2: Why was the pipeline able to execute against the wrong environment?**

Because the environment target was accepted by the deployment workflow without a mandatory pre-deployment validation that compared the selected target with the expected environment for that run.

**Why 3: Why was there no mandatory validation?**

Because environment safety depended on configuration and operator context rather than on a pipeline control that stopped execution when the target was inconsistent with the deployment purpose.

**Why 4: Why did the process depend on operator context?**

Because the deployment design treated environment selection as an operational input instead of a protected deployment boundary. The workflow could proceed once a target value was supplied, rather than requiring the target to be derived from or checked against an approved deployment context.

**Why 5: Why was environment selection not designed as a protected boundary?**

Because the pipeline had been optimized to automate deployment actions, but the design had not yet added equivalent controls for **environment identity, state validation, and safe failure**. Automation existed for performing the deployment, but not enough automation existed for preventing an unsafe deployment target.

### Structural root cause

The structural root cause was therefore **insufficient environment-target guardrails in the deployment design**.

The incident was not simply caused by someone choosing the wrong value. A production-quality deployment system should assume that incorrect input, stale state, or operator mistakes will eventually occur and should prevent those conditions from becoming service-impacting changes.

The pipeline needed a control that could answer, before any deployment action:

1. Which environment is this run permitted to modify?
2. Which environment is currently active?
3. Does the requested target match the approved deployment context?
4. Is the target healthy and in the expected pre-deployment state?
5. If any of those checks fail, does the pipeline stop before changing traffic or services?

The absence of these enforced checks allowed a configuration mistake to become an availability incident.

---

## 4. Contributing Factors

Several conditions increased the likelihood or impact of the incident.

### 4.1 Environment selection was not sufficiently constrained

The pipeline could act on an environment based on configuration or an operator-supplied target. There was no strong validation layer preventing an unintended environment from being modified.

### 4.2 The demonstration environment was actively serving the walkthrough

The deployment operation and the investor demonstration shared the same staging environment. This increased the impact of an incorrect deployment because a pipeline mistake became immediately visible to users of the demonstration.

### 4.3 Pre-deployment state was not treated as a required invariant

A safe deployment should start from a known state and verify active and previous environments before changing anything. The later blue/green process explicitly performs this reset and state verification, showing that these checks were a missing safety mechanism during the earlier incident.

### 4.4 Recovery depended on human detection and action

The earlier deployment model relied on a person noticing the problem and initiating recovery. Human response adds detection and decision time, and it makes recovery duration dependent on who is watching at the moment of failure.

The current project addresses this weakness with an automated monitor and rollback path. In the controlled test, automated recovery restored the previous version in **31 seconds**, below the 90-second requirement.

### 4.5 Environment state and deployment intent were not strongly coupled

The deployment target, active environment, and expected deployment direction needed to be checked as one consistent state. If these are handled independently, stale or incorrect values can allow the pipeline to perform a valid command against an invalid target.

---

## 5. What Went Well

The team restored staging service within **48 seconds**, limiting the duration of the investor-demo disruption.

The incident also produced a clear engineering lesson rather than being treated as an isolated operator mistake. The follow-up deployment work added explicit environment state files, health verification before traffic switching, post-switch confirmation, and automated rollback monitoring.

The controlled rollback test performed during the current project showed that the improved recovery mechanism can detect a failed release and restore the previous environment automatically. The measured fault-to-restoration time was **31 seconds**, which is comfortably inside the required 90-second recovery objective.

This demonstrates measurable improvement from a human-dependent recovery process toward a system that can detect and correct a failed deployment without waiting for manual intervention.

---

## 6. Action Items

| # | Owner role | Action | Target timeframe | Expected outcome |
|---|---|---|---|---|
| 1 | **DevOps Engineer** | Add a mandatory pre-deployment environment validation stage. The pipeline must print the requested target, current active environment, expected source environment, and intended destination, then fail before deployment if the combination is invalid. | **Within 2 working days** | An incorrect environment selection is rejected before any service or traffic change occurs. |
| 2 | **Platform Engineer** | Make environment targeting explicit and constrained by the deployment context rather than relying on an unrestricted manually supplied value. Maintain an approved mapping between deployment stage and permitted environment. | **Within 1 week** | A staging deployment cannot accidentally target an environment outside its approved scope. |
| 3 | **DevOps Engineer** | Add automated pre-switch and post-switch health validation, including verification of the active and previous environment state before a run is considered successful. | **Within 3 working days** | A deployment cannot silently leave routing and recorded environment state inconsistent. |
| 4 | **Site Reliability / Platform Engineer** | Keep automated post-deployment monitoring and rollback as a required part of every traffic switch. A failed health confidence window must restore the previous known-good environment without waiting for human action. | **Before the next release** | Release failures are detected and recovered automatically within the defined recovery target. |
| 5 | **Engineering Lead** | Require deployment evidence for high-visibility demonstrations and releases: pre-deployment state, target environment, health verification, switch result, and recovery result must be retained with the deployment record. | **Effective immediately** | Reviews can verify what environment was targeted and what happened without relying on memory. |
| 6 | **DevOps / QA Engineer** | Add an automated negative test that deliberately supplies an invalid or conflicting environment target and verifies that the pipeline refuses to deploy. | **Within 1 week** | Environment guardrails are continuously tested rather than assumed to work. |
| 7 | **Engineering Lead and DevOps Engineer** | Define a demonstration change policy so deployment experiments that can interrupt staging are either completed before the walkthrough or performed only through the validated blue/green procedure. | **Before the next investor or board demonstration** | Business demonstrations are protected from avoidable deployment-state changes. |

### Follow-up success criteria

This review is considered addressed when:

- an invalid environment target cannot pass the pre-deployment checks;
- active and previous environment state is verified before and after a traffic switch;
- a failed release automatically returns to the known-good environment;
- rollback evidence includes detection and recovery timestamps;
- the deployment process can demonstrate recovery inside the agreed 90-second objective.

The current automated rollback test already provides evidence for the recovery objective: **31 seconds from the controlled fault to confirmed restoration of the previous version through the proxy**.
