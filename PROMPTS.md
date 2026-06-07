# Prompts

A chronological log of the prompts used during the Kubernetes deployment
session, along with what each one produced.

## 1. Debug kubectl pipeline failure

> why did I got this error: [...] `kubectl --token=**** delete pod myapp
> --ignore-not-found=true` [...] couldn't get current server API group list
> [...] Authentication required

A conceptual/debugging question (no file changes). Key takeaways:

- The `kubectl` commands in the Jenkinsfile reference `${KUBE_ARGS}`, but that
  environment variable is **never defined** in the pipeline — it expands to an
  empty string.
- Without `--server`, kubectl was hitting the **Jenkins server** instead of the
  Kubernetes API server. The HTML login page in the error confirmed this.
- Fix: define `KUBE_ARGS` in the pipeline's `environment` block (or as a
  Jenkins global env var) with the correct `--server` and
  `--certificate-authority` flags pointing at the real K8s API.

## 2. Liveness vs readiness probes

> what is the difference between livenessProbe.httpGet and
> readinessProbe.httpGet

A conceptual question (no file changes). Key takeaways:

- **`livenessProbe`** — "Is the container still alive?" If it fails, Kubernetes
  **kills and restarts** the container. Detects deadlocks, infinite loops, or
  hung processes.
- **`readinessProbe`** — "Is the container ready to receive traffic?" If it
  fails, Kubernetes **removes the pod from Service endpoints** (stops routing
  traffic) but does **not** restart it. Once the probe passes again, traffic
  resumes.
- A common pattern is to use both: readiness to avoid sending traffic before
  the app is ready, liveness to recover from stuck processes.

## 3. Why memory requests/limits matter

> what can go wrong if I dont set resources.limits.memory or
> resources.requests.memory?

A conceptual question (no file changes). Key takeaways:

- Without `requests.memory`, the scheduler can place the pod on a node without
  enough memory and can overcommit nodes.
- Without `limits.memory`, a container can consume unlimited memory on the node,
  starving other pods or triggering the kernel OOM killer unpredictably.
- Kubernetes assigns a QoS class based on requests/limits: **Guaranteed**
  (requests == limits), **Burstable** (partial), or **BestEffort** (none set).
  BestEffort pods are the first to be evicted under memory pressure.

## 4. Pod IPs vs Services

> what pod ips are bad worse than services?

A conceptual question (no file changes). Key takeaways:

- Pods are ephemeral — every restart assigns a **new IP**, breaking anything
  that relied on the old one.
- Pod IPs offer no load balancing, no health-aware routing, and break when
  scaling up or down.
- A Service provides a **stable DNS name and cluster IP**, automatic load
  balancing across healthy pods, and decouples clients from individual pod
  lifecycles.
