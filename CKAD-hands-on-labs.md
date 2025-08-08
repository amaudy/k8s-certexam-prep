## CKAD Hands-on Labs

A complete CKAD-aligned lab suite you can run locally (kind or minikube). Each lab has goals, tasks, and quick verification. No external dependencies beyond kubectl + a local cluster.

### How to use
- Create a fresh cluster per session (kind or minikube).
- Do one lab per new namespace to avoid conflicts.
- Timebox: aim for 5–12 minutes per lab; CKAD rewards speed.

### Prerequisites
- kubectl v1.27+; kind or minikube
- Optional: jq, yq
- Baseline cluster (pinned to v1.33.3):
  - kind: `kind create cluster --name ckad --image kindest/node:v1.33.3`
  - minikube: `minikube start --kubernetes-version=v1.33.3`
- Note: For exam parity, pin to the version listed on the CKAD page and adjust 1.33.3 if it changes.
- Useful setup:
  - `kubectl config set-context --current --namespace=default`
  - `alias k=kubectl`

---

## Core Concepts and Pod Design

### Lab 01 — Namespaces, contexts, labels, and selectors
- Practice: namespaces, contexts, labels, field/label selectors.
- Tasks:
  - Create namespace `lab01`. Switch current context namespace to it.
  - Run a `busybox` pod with labels `app=bb, tier=dev`.
  - List pods via label selector `-l app=bb` and via field selector `--field-selector status.phase=Running`.
- Verify:
  - `kubectl get ns`
  - `kubectl get po -l app=bb -o wide`
  - `kubectl get po --field-selector status.phase=Running`

### Lab 02 — Pod basics: command, args, env
- Practice: `command`, `args`, env vars, restart policy.
- Tasks:
  - Create `pod/echo` (image `bash:5.2` or `busybox`) that prints `CKAD` and sleeps 3600.
  - Provide env `GREETING=CKAD`, output it on start.
- Verify: `kubectl logs echo | grep CKAD`

### Lab 03 — Probes: liveness, readiness, startup
- Practice: HTTP/TCP/exec probes.
- Tasks:
  - `deployment/web` (image `nginx:1.25`) replicas=2.
  - Add readiness HTTP GET `/` on 80, liveness TCP 80, startup HTTP `/`.
- Verify:
  - `kubectl get po -l app=web -w`
  - `kubectl describe po/<one> | grep -A2 -E 'Liveness|Readiness|Startup'`

### Lab 04 — Resource requests/limits and QoS
- Practice: requests/limits; observe OOM.
- Tasks:
  - Pod with `requests: cpu 100m, mem 64Mi; limits: cpu 200m, mem 96Mi`.
  - Run `stress` (or `dd` loop) to hit memory limit and observe restart.
- Verify:
  - `kubectl describe po/<pod> | grep -i oom`
  - `kubectl get po -o wide`

### Lab 05 — Multi-container Pods: sidecar, initContainer
- Practice: sidecar log shipping; init gating.
- Tasks:
  - Pod with:
    - init container `busybox` writing file `/work/ready`.
    - main `nginx`.
    - sidecar `busybox` tailing `/var/log/nginx/access.log`.
  - Share `emptyDir` as needed.
- Verify:
  - `kubectl logs <pod> -c <sidecar> -f`
  - Ensure main starts only after init completed.

---

## Application Deployment and Updates

### Lab 06 — Deployment rollouts, strategies, rollback
- Practice: rolling update, surge/unavailable, rollback.
- Tasks:
  - `deployment/api` (image `nginx:1.25`), replicas=3, strategy `maxUnavailable=0, maxSurge=1`.
  - Update image to a bad tag; observe rollout fail; rollback.
- Verify:
  - `kubectl rollout status deploy/api`
  - `kubectl rollout history deploy/api`
  - `kubectl rollout undo deploy/api`

### Lab 07 — Jobs and CronJobs
- Practice: one-off and scheduled work.
- Tasks:
  - `job/pi` runs `perl -Mbignum=bpi -wle 'print bpi(1000)'`.
  - `cronjob/hello` schedule `*/1 * * * *`, `successfulJobsHistoryLimit:1`.
- Verify:
  - `kubectl get jobs -w`
  - `kubectl get cj hello`
  - `kubectl logs job/<name>` or `kubectl logs po -l job-name=pi`

### Lab 08 — Blue/Green and Canary via Services
- Practice: traffic shifting using labels and Services.
- Tasks:
  - Service `web-svc` selects `version=v1`.
  - Deploy `web-v1` and `web-v2` (different index pages) behind same selector key `app=web` but different `version` labels.
  - Switch service selector from v1 to v2 (blue→green); alternatively canary by temporarily matching both with weight via replica ratios.
- Verify:
  - `kubectl get endpoints web-svc -o wide`
  - Curl service ClusterIP from a busybox pod.

---

## Application Environment, Config, and Security

### Lab 09 — ConfigMaps: literals, files, env, volume
- Practice: Config injection patterns.
- Tasks:
  - Create `cm app-config` from literals and a file.
  - Mount as volume at `/etc/app` and also use envFrom.
  - Validate reload behavior (no auto-reload without restart).
- Verify: `kubectl exec` to view files and env.

### Lab 10 — Secrets: generic, TLS; env and volume
- Practice: secret creation and usage.
- Tasks:
  - Create `secret db-cred` with `username`/`password`.
  - Mount as env vars and as volume; ensure base64 is decoded by container.
  - Create TLS secret `tls-cert` (self-signed ok) and mount to pod.
- Verify:
  - `kubectl get secret db-cred -o jsonpath='{.data.username}' | base64 -d`
  - `kubectl exec` and cat mounted secrets.

### Lab 11 — ServiceAccounts and imagePullSecrets
- Practice: SA assignment; restricting default.
- Tasks:
  - Create `sa app-sa`. Bind to a pod.
  - Set `automountServiceAccountToken: false` at pod level; enable at container as needed.
  - Add `imagePullSecrets` reference (dummy ok).
- Verify: `kubectl exec cat /var/run/secrets/kubernetes.io/serviceaccount/token` (should exist or not per settings).

### Lab 12 — SecurityContext (pod and container)
- Practice: runAsNonRoot, fsGroup, capabilities, readOnlyRootFilesystem.
- Tasks:
  - Pod that runs as non-root UID 1000, drops all capabilities, adds `NET_BIND_SERVICE` if needed, read-only root FS, writes via `emptyDir` with `fsGroup`.
- Verify:
  - `kubectl exec id`
  - `kubectl exec sh -c 'touch /tmp/test'` vs root FS.

### Lab 13 — Downward API and fieldRef/resourceFieldRef
- Practice: expose pod/cluster info to app.
- Tasks:
  - Inject `metadata.name`, `metadata.labels`, `status.podIP` as env.
  - Mount annotations via Downward API volume.
  - Use `resourceFieldRef` to expose container CPU limit to env.
- Verify: `kubectl exec env | grep -E 'POD_NAME|POD_IP|CPU_LIMIT'`

---

## Services, Networking, and Policies

### Lab 14 — Services: ClusterIP, NodePort, ExternalName
- Practice: service fundamentals.
- Tasks:
  - Expose `web` as ClusterIP, check endpoints.
  - Create `NodePort` and curl from node (minikube/kind).
  - Create `ExternalName` to `example.com` and resolve in a test pod.
- Verify:
  - `kubectl get svc -o wide`
  - `kubectl run -it tmp --rm --image=busybox -- nslookup <svc>`

### Lab 15 — Ingress (minikube addon or kind + ingress-nginx)
- Practice: basic rules and TLS.
- Tasks:
  - Enable ingress addon or install ingress-nginx.
  - Create ingress routes `/v1` → `web-v1`, `/v2` → `web-v2`.
  - Add TLS using `tls-cert` secret.
- Verify:
  - Curl ingress host/path from node/netshoot pod.

### Lab 16 — NetworkPolicy: default deny, allow-list
- Practice: isolate and selectively allow.
- Tasks:
  - Label namespace `net=lab16`.
  - Create default-deny ingress policy for namespace.
  - Allow traffic to `api` only from pods labeled `role=frontend`.
  - Add egress rule to allow DNS.
- Verify:
  - Use `busybox` pods to curl success/failure as expected.

---

## Observability and Troubleshooting

### Lab 17 — Logs, exec, events, describe, top
- Practice: quick triage workflow.
- Tasks:
  - Create a pod that logs every second.
  - Use `kubectl logs -f`, `--previous`.
  - Trigger a restart (e.g., exit non-zero) and inspect events.
  - If metrics-server present: `kubectl top pod`.
- Verify:
  - `kubectl get events --sort-by=.lastTimestamp | tail -n 10`

### Lab 18 — CrashLoopBackOff, ImagePullBackOff, Pending
- Practice: recognize and fix common states fast.
- Tasks:
  - Deploy a bad image tag; fix with `set image`.
  - Create pod requesting too much CPU so it stays Pending; lower requests.
  - Create probe that fails; fix probe path/timeout.
- Verify:
  - `kubectl get po -w`
  - `kubectl describe po/<name> | sed -n '/Events/,$p'`

---

## State Persistence

### Lab 19 — Volumes: emptyDir, configMap, secret, projected
- Practice: pod volumes and projected sources.
- Tasks:
  - Mount configMap and secret into one projected volume with item permissions.
  - Share `emptyDir` between init and main containers.
- Verify: `kubectl exec ls -l /etc/app`

### Lab 20 — PVC, StorageClass, and StatefulSet
- Practice: dynamic provisioning; stable identities.
- Tasks:
  - Identify default `StorageClass`.
  - Create `pvc` (ReadWriteOnce) and mount to a pod; write data.
  - Create `StatefulSet` with `volumeClaimTemplates`, headless `Service`.
  - Delete one pod and verify data persistence for that ordinal.
- Verify:
  - `kubectl get sc`
  - `kubectl get pvc,pv`
  - `kubectl exec` into `sts` pods and check files.

---

## Scheduling and Placement (lightweight but useful)

### Lab 21 — nodeSelector, affinity, taints/tolerations
- Practice: placement controls.
- Tasks:
  - Label one node `disk=ssd`.
  - Schedule a pod via `nodeSelector` and an anti-affinity on `app=web`.
  - Taint a node and add toleration to run there.
- Verify: `kubectl get po -o wide`; `kubectl describe po | grep -i toleration`

---

## Kustomize and Reusability

### Lab 22 — Kustomize overlays with kubectl -k
- Practice: manifest composition.
- Tasks:
  - Create a base with `deployment` and `svc`.
  - Create `overlays/dev` that patches image tag and replicas.
  - Apply via `kubectl apply -k overlays/dev`.
- Verify: `kubectl get deploy <name> -o yaml | yq '.spec.replicas'`

---

## Application Lifecycle

### Lab 23 — Hooks and graceful termination
- Practice: `preStop`, `terminationGracePeriodSeconds`.
- Tasks:
  - Add `preStop` sleep to observe termination.
  - Send `kubectl delete pod` and time the shutdown; confirm SIGTERM handling.
- Verify:
  - `kubectl describe po/<name> | grep -A2 'Lifecycle'`

---

## Advanced Debugging (optional but great practice)

### Lab 24 — Ephemeral containers (kubectl debug)
- Practice: injecting a debug container into a running pod.
- Tasks:
  - Create a pod without shell (e.g., `distroless`).
  - Use `kubectl debug -it <pod> --image=busybox --target=<container>`.
- Verify: You can `ls /` of target’s mount namespace if supported.

---

## Reusable quick commands (speed practice)

- Imperative generators:
  - `kubectl create deploy web --image=nginx:1.25 -n lab --dry-run=client -o yaml > web.yaml`
  - `kubectl expose deploy web --port=80 --target-port=80 --type=ClusterIP --dry-run=client -o yaml > svc.yaml`
- Rollouts:
  - `kubectl set image deploy/web web=nginx:bad && kubectl rollout status deploy/web`
  - `kubectl rollout undo deploy/web`
- Selection:
  - `kubectl get po -l app=web -o name | xargs kubectl delete`
- JSONPath:
  - `kubectl get po -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'`

---

## How to verify mastery
- Complete each lab within the timebox without looking up docs.
- Re-run selected labs under a fresh namespace with different names/tags.
- Ensure you can create manifests imperatively then refine YAML quickly.

Reference certification page: `https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/`