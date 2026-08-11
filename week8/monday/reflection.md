# Week 8 Monday Reflection: Containers

## Baseline Image

Image: `kk-payments:monday-baseline`

Measured image size: `266MB`

Docker also reported a content size of `62.2MB`.

The Monday image is intentionally a baseline implementation. It uses
`node:18-alpine`, installs all dependencies, builds the application, and
starts the service using `npm start`. Tuesday will replace this with a
smaller multi-stage production image and direct Node.js execution.

---

## Question 1: The Layer Caching Decision

The Dockerfile copies `package.json` and `package-lock.json` before copying
the rest of the application source:

1. `FROM node:18-alpine`
2. `WORKDIR /app`
3. `COPY package.json package-lock.json ./`
4. `RUN npm ci`
5. `COPY . .`
6. `RUN npm run build`
7. `EXPOSE 3000`
8. `CMD ["npm", "start"]`

If I change only one line in `src/payments.js`, Docker can reuse the cached
layers for the base image, the working directory, the package manifest copy,
and `RUN npm ci`.

The first cache miss occurs at:

`COPY . .`

This happens because the application source files have changed. Docker then
copies the changed source and reruns:

`RUN npm run build`

The dependency installation does not need to run again because neither
`package.json` nor `package-lock.json` changed.

This improves build speed because `npm ci` is normally more expensive than
copying application files.

If I instead add a new npm dependency, both `package.json` and
`package-lock.json` change. The cache first becomes invalid at:

`COPY package.json package-lock.json ./`

Docker must then rerun:

`RUN npm ci`

to install the new dependency set. The later source-copy and build layers are
also rebuilt on top of the new dependency layer.

This is why package manifests should be copied before application source code:
source changes do not unnecessarily invalidate the dependency installation
cache.

---

## Question 2: Containers and the Week 7 Deployment

The Week 7 deployment depended on the target VM already being configured in
a particular way.

### Node.js version

The tarball contained the application but depended on the VM having a
compatible Node.js version installed.

The Dockerfile replaces this dependency with:

`FROM node:18-alpine`

The Node.js runtime is now part of the image. The application therefore uses
the same runtime wherever the image is executed.

### npm and application dependencies

The Week 7 VM also needed npm and the correct application dependencies.

The container build performs dependency installation using:

`RUN npm ci`

The dependencies become part of the image instead of depending on manual
installation on the destination VM.

### Directory structure

The Week 7 deployment expected particular directories to exist on the VM for
extracting and running the application.

The Dockerfile defines its own application directory:

`WORKDIR /app`

and places the application into it using:

`COPY . .`

The filesystem structure required by the application therefore exists inside
the image.

### Service management and service account

Week 7 relied on a systemd unit being installed and configured to start the
application. The VM also needed the correct service account and permissions.

With Docker, the application startup command is defined by `CMD`, and Docker
manages the container lifecycle.

The Monday baseline uses:

`CMD ["npm", "start"]`

Tuesday will improve this to direct Node.js execution and will also introduce
a non-root runtime user.

Instead of manually configuring the complete application runtime on every VM,
the main host dependency becomes having a compatible container runtime such
as Docker.

---

## Question 3: CMD Exec Form vs Shell Form

The Monday Dockerfile uses:

`CMD ["npm", "start"]`

This is Docker exec-form syntax, but the problem is that npm becomes the main
process inside the container instead of the Node.js application.

The process structure is approximately:

`Docker -> npm -> node -> application`

The npm process becomes PID 1, while the Node.js application runs as a child.

When Docker stops a container, it sends `SIGTERM` to PID 1. In this case the
signal is first received by npm. Signal forwarding through npm to the child
Node.js process may not behave the same way as sending the signal directly to
the application.

The improved command is:

`CMD ["node", "dist/index.js"]`

The process structure then becomes:

`Docker -> node`

Node.js itself becomes PID 1. When Docker sends `SIGTERM`, the Node.js
application receives it directly and can perform graceful shutdown.

For a payment service, graceful shutdown is important because requests may be
in progress when a deployment or container stop happens.

If the application does not receive or handle the termination signal
properly, Docker may eventually terminate it forcefully. Users could
experience interrupted requests, timeouts, or retries during deployment.

Starting Node.js directly therefore gives the application better control over
its shutdown lifecycle.

---

## Question 4: What the Container Does Not Yet Solve

The container image should contain the application and the runtime needed to
execute it, but it should not contain every piece of configuration.

Two important categories should remain outside the image.

### Secrets and credentials

Examples include:

- database passwords
- API credentials
- access tokens
- encryption keys

These values should not be copied into the image.

Putting secrets in a `.env` file and then copying that file into the Docker
image is an anti-pattern because the sensitive values can become part of the
image filesystem or image layers.

The `.dockerignore` therefore excludes environment files such as:

`.env`

Runtime values can instead be supplied when the container starts using the
`-e` flag.

For example:

`docker run -e DATABASE_HOST=db-staging kk-payments:monday-baseline`

The environment variable is supplied to the running container instead of
being permanently built into the image.

### Environment-specific configuration

Development, staging, and production may require different values for:

- database hosts
- service URLs
- application ports
- logging configuration
- feature settings

These values should also remain outside the image.

For example, the same image could run as:

`docker run -e APP_ENV=development kk-payments:monday-baseline`

or:

`docker run -e APP_ENV=production kk-payments:monday-baseline`

The application image remains unchanged while its runtime configuration is
different.

This supports the idea of building an image once and running the same image
in multiple environments.

Later in Week 8, runtime configuration for multiple containers will be
managed in a more structured way rather than passing many individual `-e`
options manually. The material provided so far does not yet name that
mechanism, but the principle remains the same: configuration is supplied at
runtime rather than baked into the container image.