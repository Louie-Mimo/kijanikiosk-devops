# Week 8 Tuesday Reflection: Production Dockerfile

## Question 1: The Layer Deletion Trick Explained

Docker images are built as a sequence of immutable filesystem layers. Each
Dockerfile instruction that changes the filesystem creates a new layer on top
of the previous layers.

For example, if a Dockerfile installs all dependencies using:

```dockerfile
RUN npm ci

the resulting layer contains both production dependencies and development
dependencies such as Jest or TypeScript.

A later instruction may try to reduce the image by running:

RUN npm run build && rm -rf node_modules && npm ci --only=production

The rm -rf node_modules command removes the files from the filesystem view
of the new layer, but it does not remove the files from the earlier layer in
which npm ci originally created them.

Docker layers are immutable. Therefore, the previous layer still contains the
development dependencies and their bytes still contribute to the total image
size. The later layer only records that those files should no longer appear in
the final merged filesystem.

This is why deleting build tools or devDependencies in a later layer does not
recover the space already consumed by an earlier layer.

Multi-stage builds solve the problem differently. The builder stage is allowed
to contain all development dependencies, source code, test tools, and build
tools:

FROM node:18-alpine AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

The production stage then begins from a separate clean base image:

FROM node:18-alpine AS production

Only the files needed at runtime are copied from the builder stage:

COPY --from=builder /app/dist ./dist

The production stage does not inherit the builder stage's node_modules,
source files, test framework, or other build-time layers.

Therefore, the unwanted files are not deleted from the production image;
they were never included in the production stage in the first place. This is
why multi-stage builds provide a much cleaner separation between build-time
and runtime dependencies.

Question 2: The start-period Parameter

The Docker HEALTHCHECK uses --start-period=15s. The purpose of the start
period is to give the application time to initialize before failed health
checks begin counting toward the configured retry limit.

Assuming the Tuesday health check uses:

--interval=10s
--start-period=15s
--retries=3

and kk-payments v1.5.0 requires 25 seconds to warm up its connection pool, the
sequence would be approximately:

0s      Container starts
10s     Health check fails - ignored during start-period
15s     start-period ends
20s     Health check fails - failure 1 of 3
25s     Application finishes warming up
30s     Health check succeeds

The health check at approximately 10 seconds fails because the service is
still warming up. Since it occurs during the 15-second start period, that
failure does not count toward the three configured retries.

The next check occurs at approximately 20 seconds. The start period has ended,
but the service is still warming up, so this failure counts as failure 1 of 3.

At approximately 25 seconds, the application finishes warming up. The next
health check, at approximately 30 seconds, succeeds. The successful check
resets the consecutive failure count.

Therefore, in this specific 25-second warm-up scenario, the container would
not actually reach the three consecutive failures required to be marked
unhealthy.

If warm-up took longer, the failures would continue as:

Failure 1
Failure 2
Failure 3 -> container becomes unhealthy

For example, if checks continued failing at 20, 30, and 40 seconds, the third
counted failure would cause the container to be marked unhealthy.

Operationally, an incorrectly configured start period can make a normally
starting application appear unhealthy before initialization is complete.

In the Kubernetes deployment scenario described in the lab, where this health
status is being used as the readiness signal, the consequence would be that
the new kk-payments instance could be treated as unavailable and traffic would
not be routed to it.

For a payments service, this is important because a Pod should not receive
transaction requests until resources such as database connections and
connection pools are ready.

The start-period should therefore reflect the application's realistic
startup time rather than an arbitrary value.

Question 3: Why Non-Root Matters for kk-payments Specifically

Running kk-payments as a non-root user is especially important because it is a
financial transaction service and is therefore a high-value security target.

If an attacker discovers a vulnerability that allows arbitrary code execution
inside a container running as root, the attacker's code would execute with
root privileges inside that container.

Depending on the other container security controls, this could allow the
attacker to:

modify application files
replace scripts or binaries
alter configuration
access files restricted to root
tamper with writable logs
install or execute additional tools
interfere with other processes inside the container
increase the impact of another container or host vulnerability

Root inside a container is not automatically equivalent to unrestricted root
access on the Docker host because container isolation still applies. However,
running the application as root unnecessarily increases the privileges
available to an attacker after a successful compromise.

For a payments application, reducing the impact of a compromise is especially
important because the service processes financial requests and may communicate
with databases and other financial systems.

The Dockerfile therefore creates a dedicated runtime user:

RUN addgroup -S kijani && \
    adduser -S kijani -G kijani

and later switches to that user:

USER kijani

This means the Node.js application runs with the permissions of kijani
instead of root.

The ownership change is also important:

RUN chown -R kijani:kijani /app

Dockerfile instructions normally execute as root before the USER instruction
is reached. Files copied into /app may therefore be owned by root.

Once the Dockerfile switches to:

USER kijani

the application no longer has root privileges. If it needs access to files or
writable locations under /app, incorrect ownership could result in
permission errors.

Changing ownership ensures the application directory has the intended owner
before the container drops root privileges.

The correct sequence is therefore:

1. Create the kijani user and group
2. Install production dependencies
3. Copy the application files
4. Set ownership to kijani
5. Switch to USER kijani
6. Start the Node.js process

USER kijani reduces runtime privileges, while chown kijani:kijani /app
ensures the application can operate correctly with those reduced privileges.

The two instructions work together to provide both security and correct
runtime permissions.

Question 4: The Builder Stage in the CI Pipeline

The Week 5 Jenkins pipeline ran npm test directly on the Jenkins agent host.
With the multi-stage Dockerfile, testing should instead be performed using the
Docker builder stage.

The builder stage is the correct stage because it contains all dependencies,
including development dependencies such as Jest.

The production stage intentionally contains only runtime dependencies.
Development and testing tools should not be installed in the production image.

The first CI step should therefore build the builder target:

docker build \
  -f Dockerfile.production \
  --target builder \
  -t kijanikiosk/kk-payments:${BUILD_TAG}-builder \
  .

Jenkins can then execute the tests inside that builder image:

docker run --rm \
  kijanikiosk/kk-payments:${BUILD_TAG}-builder \
  npm test

If the test command fails, the Jenkins pipeline should stop and the production
image should not be pushed.

For the current Tuesday lab, the builder image was also verified to contain
Jest using:

docker run --rm \
  kijanikiosk/kk-payments:v1.0.0-builder \
  npm list jest

which returned:

payments@1.0.0 /app
`-- jest@30.4.2

This proves that the builder stage contains the development toolchain while
the production image does not.

After the test stage succeeds, Jenkins should build the production target:

docker build \
  -f Dockerfile.production \
  --target production \
  -t kijanikiosk/kk-payments:${IMAGE_TAG} \
  .

Only the production image should then be tagged and pushed to the container
registry.

The Jenkins pipeline therefore changes conceptually from:

Jenkins agent
    |
    +-- npm install
    |
    +-- npm test
    |
    +-- build/deploy

to:

Jenkins
    |
    +-- Build Docker builder stage
    |
    +-- Run npm test inside builder image
    |
    +-- Tests pass?
           |
           +-- No -> stop pipeline
           |
           +-- Yes
                 |
                 +-- Build production stage
                 |
                 +-- Tag production image
                 |
                 +-- Push production image