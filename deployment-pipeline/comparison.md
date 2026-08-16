# KijaniKiosk Deployment Approach Comparison

## Executive Comparison

KijaniKiosk has now tested two ways of keeping the payment service available during change and failure. The first keeps two separate application environments and moves customer traffic between them. The second packages the application once and runs multiple copies under a platform that maintains the required number of healthy instances.

The evidence shows that both approaches improve reliability, but they address different risks.

The earlier release process depended on a person noticing a bad release and starting recovery. That earlier recovery took about four minutes. In this project, the same release-failure scenario was handled automatically: the failed new version was detected and the previous healthy version was restored in **31 seconds**. This removes much of the delay caused by waiting for someone to notice the problem and act.

The newer platform also protects against individual application-instance failure. During the fresh deployment test, one running copy of the payment service was deliberately removed. A second copy stayed available while the missing one was replaced. The replacement reached the running state in **20 seconds**, and full two-copy availability was restored without manual action. A single failed copy therefore did not automatically become a full service outage.

Packaging efficiency improved as well. The earlier single-stage application image measured **266 MB**. The final production image measured **90.1 MB**, a reduction of **175.9 MB**, or about **66.1%**. This means less data must be stored and transferred when a new copy is started. The final package also excludes development-only tools and runs with a restricted user, leaving less unnecessary software in production.

## Detailed Comparison

| Concern | Blue/green approach | Container approach |
|---|---|---|
| **Deployment mechanism** | Two environments, blue and green, hold different versions. nginx switches traffic after the target environment passes validation. | A versioned container image is stored in a private registry. A Kubernetes Deployment maintains at least two Pods from that image. |
| **Rollback mechanism** | `post-deploy-monitor.sh` detects repeated failures and invokes `rollback.sh`, which uses `switch-env.sh` to return nginx traffic to the previous environment. The measured rollback was **31 seconds**. | Kubernetes reconciliation replaces failed Pods automatically. A release-version rollback would use a Deployment rollout to a previously known image version. |
| **Failure recovery** | The previous release stays available so traffic can be moved back when the new release fails. | Two replicas provide continuity. In the fresh test, one Pod stayed up while the deleted Pod was replaced. The new Pod reached Running in **20 seconds** and Ready in **27 seconds**. |
| **Scaling** | More capacity requires additional application instances and corresponding traffic configuration. | The replica count can be increased, the scheduler places additional Pods where resources fit, and the Service provides a stable access point. |

## What the Evidence Means for KijaniKiosk

For a payment service, continuity matters more than choosing one method simply because it is newer. The measurements show that keeping more than one healthy copy running greatly reduces the impact of an isolated failure. When one copy was removed, the other remained available and the platform restored the missing capacity automatically.

The separate-environment method remains valuable for release safety. It keeps the previous version ready and makes it possible to return customers to that version quickly if a new release is defective. The automated test reduced recovery from the earlier four-minute human response to 31 seconds. That directly addresses the business risk in the project brief: a bad release should be removed before it can affect large numbers of payment requests.

The packaged approach improves consistency between build and runtime environments. The same production package can be stored, retrieved, and started without rebuilding it differently at every stage. Its version is tied to a source revision, so a release can be traced back to the committed code that produced it.

The reduction from 266 MB to 90.1 MB also matters operationally. A smaller production package takes less space and requires less data transfer when new instances are created. This supports faster distribution and avoids carrying development tools into production.

The two measured recovery times should not be treated as competing measurements because they represent different failures. The **31-second** result measures recovery from a bad release by restoring the previous version. The **20-second** result measures recovery from losing one running application copy while another copy continues serving. Together, they show that release failure and instance failure can both be handled with much less human involvement.

The strongest production direction therefore combines the useful ideas from both approaches: a known-good release that can be restored quickly, more than one healthy application copy, automatic recovery when a copy disappears, versioned production packages, and evidence showing that recovery meets a defined business target.

The container approach still does not fully solve environment-specific configuration. Database addresses, credentials, external service settings, and other values can differ between staging and production and should not be built into the application package. The next orchestration stage adds centrally managed configuration and protected secret handling, together with stronger release controls, scaling, and traffic management, so the same application package can move safely between environments without being rebuilt.
