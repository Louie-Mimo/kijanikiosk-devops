# Week 8 Wednesday Reflection: Private Registries

## Question 1: The Semver-SHA Tag and Rollback

The registry contains two versioned images:

- `1.0.0-a3f2c8b`
- `1.0.0-d9e1f4a`

If production is currently running `1.0.0-d9e1f4a` and that version has a critical bug, the rollback should point the Kubernetes Deployment back to the known-good image `1.0.0-a3f2c8b`.

The field that changes is the container image in the Deployment manifest:

```yaml
spec:
  template:
    spec:
      containers:
        - name: kk-payments
          image: ghcr.io/kijanikiosk/kk-payments:1.0.0-a3f2c8b
```

The current value:

```yaml
image: ghcr.io/kijanikiosk/kk-payments:1.0.0-d9e1f4a
```

is replaced with:

```yaml
image: ghcr.io/kijanikiosk/kk-payments:1.0.0-a3f2c8b
```

The updated manifest is then applied using:

```bash
kubectl apply -f deployment.yaml
```

Kubernetes compares the new desired state with the current state and replaces Pods running the faulty image with Pods running the known-good image.

The semver-SHA tag is important because it identifies an exact build. The rollback does not depend on a mutable tag such as `latest`.

This is similar to the Week 7 rollback because both approaches restore a known-good version of the application.

In Week 7, rollback was handled imperatively using a script such as:

```text
rollback.sh
```

The script switched the nginx upstream from the faulty version back to the previous version.

Conceptually:

```text
Week 7

New version fails
      |
      v
rollback.sh
      |
      v
Change nginx upstream
      |
      v
Traffic returns to previous version
```

With Kubernetes, the rollback is based on desired state:

```text
Kubernetes

New version fails
      |
      v
Change Deployment image tag
      |
      v
kubectl apply
      |
      v
Kubernetes replaces Pods
      |
      v
Previous image is running again
```

The similarity is that both mechanisms rely on a previously known-good version.

The main difference is that Week 7 scripts and nginx explicitly controlled which instance received traffic, while Kubernetes is given the desired image version and automatically reconciles the running Pods to match that desired state.


## Question 2: The ImagePullSecret Lifecycle

The ImagePullSecret `kijani-registry-credentials` contains credentials that Kubernetes uses to authenticate to the private registry.

If the GitHub Personal Access Token expires after 90 days, Pods that are already running continue to work because the image has already been pulled to the node.

The problem appears when Kubernetes needs to pull the image again, for example when:

- the Deployment scales up
- a Pod is recreated
- a node fails and the Pod is rescheduled
- a new deployment occurs
- a node does not already have the required image

At that point, the registry rejects the expired credential and the new Pod cannot pull the private image.

The rotation procedure is:

### 1. Create a new registry credential

A new valid GitHub Personal Access Token is created with the permissions required to pull the private image.

The expired token is then retired or revoked.

### 2. Update the Kubernetes Secret

The Kubernetes Secret is recreated or updated with the new registry credential while keeping the same Secret name:

```text
kijani-registry-credentials
```

The credential value changes, but the logical Secret name remains the same.

### 3. Keep the Deployment reference unchanged

The Deployment manifest contains only the Secret reference:

```yaml
imagePullSecrets:
  - name: kijani-registry-credentials
```

The actual token is not stored in the Deployment.

Therefore, the Deployment manifest does not need to change when the registry credential is rotated.

The relationship remains:

```text
Deployment
    |
    | references Secret name
    v
kijani-registry-credentials
    |
    | contains current registry credential
    v
Private registry
```

This follows the same credential-management principle used in Week 5 with Jenkins and Nexus.

In Week 5, the Jenkinsfile referenced a credential identifier such as:

```text
credentialsId: 'nexus-credentials'
```

The actual username and password were stored in Jenkins.

When the Nexus credential changed, the secret value in Jenkins was updated while the Jenkinsfile continued to use the same credential ID.

The Kubernetes equivalent is:

```text
Week 5
Jenkinsfile
    |
    v
credentialsId: nexus-credentials
    |
    v
Jenkins credential store


Week 8
Deployment manifest
    |
    v
imagePullSecrets:
  - name: kijani-registry-credentials
    |
    v
Kubernetes Secret
```

In both cases, the reference can safely exist in version control while the credential value is managed separately.


## Question 3: The latest Tag in CI Pipelines

Using `latest` as the image version in a Kubernetes Deployment makes deployments less deterministic.

For example:

```yaml
image: ghcr.io/kijanikiosk/kk-payments:latest
```

does not identify one specific build.

The meaning of `latest` changes whenever CI pushes another image using the same tag.

Suppose a Deployment is running three Pods and `latest` originally points to build A. CI later moves `latest` to build B.

During a rolling update or when Pods are recreated, some nodes may pull build B while existing Pods may still be running build A. The Deployment can therefore temporarily or unexpectedly contain different application builds even though every Pod specification says `latest`.

This creates a reproducibility and traceability problem.

It also makes rollback harder because the manifest does not identify the exact build that was previously running.

By contrast, a semver-SHA tag such as:

```text
1.0.0-a3f2c8b
```

identifies a particular build and source revision.

A Kubernetes manifest using:

```yaml
image: ghcr.io/kijanikiosk/kk-payments:1.0.0-a3f2c8b
```

can be traced directly to that version and Git commit.

The preferred production flow is therefore:

```text
Source commit
      |
      v
Build image
      |
      v
1.0.0-a3f2c8b
      |
      v
Push registry
      |
      v
Deployment references exact tag
```

Tagging an image as `latest` in addition to the immutable versioned tag can still be acceptable as a convenience for developers.

For example, CI could publish both:

```text
kk-payments:1.0.0-a3f2c8b
kk-payments:latest
```

The important precaution is that production Kubernetes manifests must continue to reference the immutable semver-SHA tag rather than `latest`.

In that case, `latest` is only a convenience alias for manual development use, while production remains reproducible and traceable.


## Question 4: Registry, Nexus, and the Delivery Pipeline

Nexus and the container registry store artifacts at different stages of the delivery process.

Nexus, introduced in Week 5, stores application or package artifacts such as npm packages or tarballs.

The container registry stores complete Docker images that contain the runtime form of the application.

A simplified delivery flow is:

```text
Source code
    |
    v
Build and test
    |
    v
npm package / tarball
    |
    v
Nexus
    |
    v
Docker build
    |
    v
Container image
    |
    v
Container registry
    |
    v
Kubernetes
```

The npm tarball is superseded as the deployment unit once the production Docker image has been successfully built.

Kubernetes does not deploy the npm tarball directly. It pulls the final container image from the private container registry.

The multi-stage Docker build makes the relationship clearer.

The builder stage contains the complete development environment:

```text
Builder stage
-------------------------
Node.js
npm
source code
devDependencies
test tools
build tools
compiled output
```

The builder stage produces the application output needed by the runtime.

The production stage then starts from a clean runtime image and copies only the required runtime output:

```dockerfile
COPY --from=builder /app/dist ./dist
```

The production image therefore contains only what is needed to run the service, such as:

```text
Production image
-------------------------
Node.js runtime
production dependencies
compiled application output
runtime configuration
```

The npm tarball does not normally remain as a tarball inside the final container image unless the Dockerfile deliberately copies it there. Its useful contents are installed, extracted, built, or copied into the runtime filesystem.

Adopting containers does not make Nexus irrelevant.

Nexus can still provide:

- storage for versioned application packages
- storage for reusable internal npm packages
- dependency distribution
- build inputs for CI
- artifact history
- traceability between pipeline stages

The container registry has a different responsibility:

- storing deployable Docker images
- versioning images using tags
- allowing Kubernetes to pull images
- providing the final runtime artifact used during deployment

The two stores therefore represent different artifact boundaries:

```text
Nexus
  |
  | application/package artifacts
  v
Docker build
  |
  | packages application + runtime
  v
Container Registry
  |
  | deployable image
  v
Kubernetes
```

Nexus continues to serve software package management, while the container registry becomes the source of the deployable runtime image.

The semver-SHA convention connects the container image to source control so that the team can identify exactly which source revision produced a particular deployable image.
