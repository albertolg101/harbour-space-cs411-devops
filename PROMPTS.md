# Prompts

A chronological log of the prompts used to build the containerization and
CI/CD pipeline for this project, along with what each one produced.

## 1. Containerize the app

> add a Dockerfile to the repo, use golang:1.24

Created a multi-stage `Dockerfile`. Since the app has no `go.mod`, the binary
is built directly from the file (`go build main.go`). A static binary
(`CGO_ENABLED=0`) is produced in the `golang:1.24` build stage and copied into
a minimal runtime stage. Exposes port `4444`.

## 2. CI/CD: build and push the image

> following the same pattern used in this Jenkinsfile [...] add a new one that
> runs docker build and tags the image as ttl.sh/albertolg101:2h and push it

Added Build + Push stages to the `Jenkinsfile` that build the image and push it
to `ttl.sh` (anonymous ephemeral registry; the `:2h` tag expires after 2h, no
credentials needed).

## 3. CI/CD: deploy stage

> Add a Jenkins stage that runs on the docker machine. Pull the image from
> ttl.sh. Run the container with -p 4444:4444 so the app is reachable on the
> VM's :4444.

Added a Deploy stage. After a couple of iterations (label mismatch, raw SSH)
the deploy was switched to **Ansible**:

> lets use ansible

The Deploy stage now runs `ansible-playbook` over the `docker-ssh-key`
credential, using an inline inventory (`-i "$DEPLOY_HOST,"`). A new
`playbook.yml` pulls the image, removes any old container, and runs it with
`-p 4444:4444`.

## 4. Container restart policy

> lets add restart on failure
>
> lets use unless-stopped

Added `--restart unless-stopped` to the `docker run` in `playbook.yml` so the
container survives crashes and VM reboots.

## 5. Healthcheck

> lets add healthcheck directive. Add
> `HEALTHCHECK --interval=10s --timeout=2s CMD wget -qO- http://localhost:4444/ || exit 1`
> to the Dockerfile.

Added the `HEALTHCHECK`. Because distroless has no shell or `wget`, the runtime
base was switched to `alpine:3.20`, which bundles BusyBox `wget`.

## 6. Discussion: healthchecks in Kubernetes

> what does k8s do with healthcheck? why does it need it?

A conceptual question (no file changes). Key takeaways:

- Kubernetes **ignores** the Dockerfile `HEALTHCHECK` directive — that's a
  Docker/Compose feature. K8s uses its own **probes** defined in the Pod spec.
- **Liveness probe**: if it fails, K8s restarts the container (self-healing for
  hung-but-running processes).
- **Readiness probe**: if it fails, K8s removes the Pod from the Service
  endpoints (no traffic) without restarting — enables zero-downtime rollouts.
- **Startup probe**: gates liveness/readiness until a slow app has booted.
- `httpGet` probes are run by the kubelet, so no `wget`/`curl` is needed inside
  the container (one reason distroless works fine in K8s).

## 7. Pin base images by digest

> Pin base image by digest, not :latest or version tag. Change FROM golang:1.24
> to FROM golang:1.24@sha256:<digest> (pin both stages if multi-stage)

Pinned both stages to their multi-arch index digests (digests fetched with
`docker buildx imagetools inspect`):

- `golang:1.24@sha256:d2d2bc1c84f7e60d7d2438a3836ae7d0c847f4888464e7ec9ba3a1339a1ee804`
- `alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc`
