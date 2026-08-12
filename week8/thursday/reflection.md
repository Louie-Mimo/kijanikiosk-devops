# Week 8 Thursday Reflection: Kubernetes Objects

## Question 1: The Declarative Model and `kubectl apply`

Kubernetes uses a declarative model: the manifest describes the desired state, and the controllers continuously reconcile the actual state toward it.

If I run:

```bash
kubectl apply -f kk-payments-deployment.yaml
```

and then run the exact same command again thirty minutes later without changing the file, Kubernetes compares the submitted configuration with the existing Deployment and finds that the desired state is already satisfied. No new Pods are created and the ReplicaSet is not replaced simply because the same manifest was applied again.

The command normally reports:

```text
deployment.apps/kk-payments unchanged
```

This demonstrates that `kubectl apply` is idempotent.

If I change only:

```yaml
replicas: 2
```

to:

```yaml
replicas: 3
```

and apply the manifest again, the Deployment object's desired replica count changes. Kubernetes then sees that only two Pods exist while three are desired. The Deployment controller scales the current ReplicaSet from two replicas to three, and that ReplicaSet creates one additional Pod.

The existing two Pods are not replaced because the Pod template, including the image and container configuration, did not change. Only the replica count changed.

```text
Manifest: replicas = 3
        |
        v
Deployment desired state changes
        |
        v
Controller observes only 2 Pods
        |
        v
Current ReplicaSet scales to 3
        |
        v
One additional Pod is created
        |
        v
Actual state reaches 3 replicas
```

The API update happens quickly, but the new Pod becoming Running and Ready is asynchronous. The exact duration depends on scheduling, image availability, container startup and readiness checks.

This is the reconciliation loop in practice: Kubernetes continuously compares desired state with actual state and performs only the changes needed to make them match.


## Question 2: Resource Requests, Limits, and the Scheduler

For this reflection question, the Deployment specifies:

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

A request is used by the scheduler when deciding whether a Pod can fit on a node. A limit constrains how much of the resource the container can consume at runtime.

### (a) The kk-payments Pod tries to allocate 300MB of memory

The container has a memory limit of `256Mi`. If it attempts to use approximately 300MB, it exceeds that limit.

Memory is not handled like CPU throttling. When the process exceeds its memory limit, the container can be terminated by the operating system's memory-control mechanism. Kubernetes reports the termination reason as:

```text
OOMKilled
```

Because the container is running in a Pod managed by a Deployment, Kubernetes will normally restart the failed container according to the Pod's restart policy.

For a payment service, repeated memory-limit breaches would therefore appear as container restarts and temporary loss of that particular Pod until it becomes healthy again.

### (b) A third replica is added when the node has only 100MB unallocated

The important value for scheduling is the Pod's **request**, not its limit.

kk-payments requests:

```text
64Mi memory
```

If the node genuinely has about 100MB of allocatable requested-memory capacity remaining, the 64Mi request still fits. Therefore, the third Pod can be scheduled, assuming its CPU request and other scheduling constraints also fit.

It would not become `Pending` merely because its 256Mi memory limit is greater than the currently unallocated amount. Kubernetes schedules using requests.

A Pod would remain:

```text
Pending
```

with an insufficient-memory scheduling event if the node had less remaining allocatable requested-memory capacity than the Pod's 64Mi request and no other suitable node existed.

So for the exact numbers in this question:

```text
100MB remaining
64Mi requested
      |
      v
Request fits
      |
      v
Pod may be scheduled
```

If less than 64Mi were available, the Pod would remain Pending.

### (c) A second workload has no resource requests and consumes all available memory

A workload with neither CPU/memory requests nor limits is normally classified as `BestEffort`.

The kk-payments Pods have resource requests and limits, so they are in the `Burstable` QoS class.

If the second workload consumes memory until the node experiences memory pressure, Kubernetes' eviction manager can evict Pods to protect the node. `BestEffort` Pods are generally the most vulnerable to eviction before `Burstable` and `Guaranteed` workloads, subject to actual usage and eviction rules.

Therefore, the resource behaviours are:

```text
Container exceeds memory limit
        -> OOMKilled

Pod request cannot fit on a node
        -> Pending

Node experiences memory pressure
        -> eviction may occur, with BestEffort workloads most vulnerable
```

Requests and limits therefore solve different problems: requests guide scheduling and capacity reservation, while limits constrain runtime consumption.


## Question 3: The Service Selector and the Deployment Update

The `kk-payments-service` selects Pods using:

```yaml
selector:
  app: kk-payments
```

During a rolling update from `v1.0.0` to `v1.1.0`, both old and new Pods still carry:

```yaml
app: kk-payments
```

Therefore, while both versions have Ready Pods matching the selector, the Service can route traffic to **both versions simultaneously**.

The Service does not choose endpoints based on the image tag. It selects Ready endpoints based on labels.

During part of the update the topology can look like:

```text
kk-payments-service
        |
        +----> Pod A - v1.0.0
        |
        +----> Pod B - v1.0.0
        |
        +----> Pod C - v1.1.0
```

As the rolling update continues, old Pods are terminated and new `v1.1.0` Pods become Ready until the old version disappears completely.

This is conceptually the same mixed-version condition discussed in the Week 7 rolling deployment model: more than one application version can serve requests during the transition. The difference is that Kubernetes controls the transition through the Deployment controller instead of custom deployment scripts.

The fields that control how many old and new Pods coexist are:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: ...
    maxSurge: ...
```

`maxUnavailable` controls how many desired replicas may be unavailable during the rollout.

`maxSurge` controls how many extra Pods may temporarily exist above the desired replica count.

In today's lab, `kubectl describe deployment kk-payments` reported:

```text
RollingUpdateStrategy: 25% max unavailable, 25% max surge
```

because explicit values were not supplied in the manifest.

The readiness probe also matters because a new Pod should not become a Service endpoint until Kubernetes considers it Ready. This helps prevent traffic from being routed to a new version before it can successfully serve requests.

Mixed versions during a rolling update are therefore expected, but the Deployment strategy and readiness state control the transition.


## Question 4: Kubernetes vs Week 7 Deployment Model

Kubernetes gives kk-payments automated desired-state reconciliation and self-healing that the Week 7 deployment model did not provide automatically.

Today's Phase 4 test provides direct evidence.

Before deletion, the Deployment had two running Pods. I deliberately deleted:

```text
kk-payments-84b787597f-k8ztx
```

The second Pod remained running:

```text
kk-payments-84b787597f-mb7j4
```

Kubernetes detected that the actual replica count had fallen below the declared:

```yaml
replicas: 2
```

and automatically created the replacement:

```text
kk-payments-84b787597f-2rthv
```

The measured result from the lab was:

```text
T0 (Pod deleted):       08:22:17
Replacement Running:    08:22:30
Recovery to Running:    13 seconds
Replacement Ready:      08:22:39
Recovery to Ready:      22 seconds
Deployment final state: 2/2 available
```

The required T0-to-T1 self-healing result is therefore:

```text
13 seconds to Running
```

During the replacement, one replica remained available. This demonstrates why two replicas are an availability decision as well as a capacity decision. The surviving Pod could continue serving traffic while Kubernetes restored the missing replica.

With only one replica, there would have been no healthy kk-payments Pod during the replacement period. With two replicas, the Service could continue using the surviving endpoint.

The Week 7 model achieved controlled deployment and rollback differently. It used blue/green application instances, deployment scripts and nginx upstream switching. Rollback required the operational mechanism to invoke the rollback procedure and switch traffic back to the known-good environment.

```text
Week 7
-------
Detect deployment problem
        |
        v
Run rollback procedure
        |
        v
Switch nginx upstream
        |
        v
Known-good environment receives traffic


Week 8 Kubernetes
-----------------
Pod disappears
        |
        v
Deployment detects 1/2 replicas
        |
        v
ReplicaSet automatically creates replacement
        |
        v
Service continues through surviving Pod
        |
        v
Deployment returns to 2/2
```

The exact measured Week 7 blue/green rollback duration is not present in the evidence currently available to this reflection, so I should not invent a numeric value. The Week 7 reflection's recorded rollback time should be inserted here if the instructor requires the exact numeric side-by-side comparison.

The evidence-supported comparison is that Week 7 rollback depended on an explicit rollback script and nginx traffic switch, whereas today's Kubernetes Pod failure required no manual application restart or traffic change. Kubernetes restored the missing replica automatically in 13 seconds.

One thing the Week 7 model handled explicitly that this week's Kubernetes lab does not yet address is **environment-specific configuration**.

The current Kubernetes Deployment still places environment-specific values directly in the manifest. Real staging and production environments may require different database connection strings, API endpoints, credentials and other configuration.

The next Kubernetes-native step is to externalise these values using ConfigMaps and Secrets. This allows the same application image and largely the same Deployment definition to move between environments while environment-specific values are managed separately.

Kubernetes has therefore added declarative deployment, automated reconciliation, self-healing, replica-based continuity and stable Service addressing. The next operational layer is separating configuration and secrets from the Deployment manifest.
