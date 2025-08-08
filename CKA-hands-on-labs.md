## CKA Hands-on Labs

Hand on lab to prepare my self for CKA Certification exam.


### Prerequisites
- Ubuntu Server 20.04/22.04+ DigitalOcean droplets (3 nodes: 1 control-plane, 2 workers) with sudo and internet access
- kubectl within one minor of cluster
- k8s version pin: v1.33.3

### Quick setup
- Track A (kubeadm, containerd, CRI):
  ```bash
  # On all nodes
  sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
  sudo modprobe overlay && sudo modprobe br_netfilter
  cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
  net.bridge.bridge-nf-call-iptables  = 1
  net.ipv4.ip_forward                 = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  EOF
  sudo sysctl --system
  
  sudo apt-get install -y containerd
  sudo mkdir -p /etc/containerd && containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
  sudo systemctl enable --now containerd
  
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
  ```

Note: For exam parity, pin to the exact version the CKA uses on the official page.

If you provision droplets with Terraform in `manual-cluster/`, see `kubeadm-cluster-setup.md` for a step-by-step cluster bring-up on Ubuntu 22.04.

---

## Cluster Architecture, Installation & Configuration

### Lab 01 — Initialize a cluster (kubeadm)
- Goal: Bring up a single control-plane cluster with a CNI.
- Tasks:
  - On control-plane: `kubeadm init --pod-network-cidr=10.244.0.0/16`
  - Configure kubeconfig for the admin user.
  - Apply a CNI (Calico or Flannel).
  - Join two workers with the printed `kubeadm join` command.
- Verify:
  - `kubectl get nodes -o wide`
  - `kubectl -n kube-system get ds`

### Lab 02 — Verify multi-node cluster (kubeadm)
- Goal: Confirm roles, scheduling, and basic networking on DigitalOcean droplets.
- Tasks:
  - Label workers and confirm control-plane taint present.
  - Deploy a simple nginx Deployment with 2 replicas; expose via ClusterIP; exec curl from a busybox pod.
  - Confirm pods are spread across workers; check `kube-proxy` and `coredns` health.
- Verify:
  - `kubectl get nodes -o wide`
  - `kubectl get deploy,rs,po,svc -A -o wide`

### Lab 03 — Configure container runtime & kubelet
- Goal: Ensure containerd + kubelet healthy.
- Tasks:
  - Check `systemctl status containerd kubelet`.
  - Ensure swap off; verify `--cgroup-driver` alignment.
- Verify:
  - `journalctl -u kubelet -n 50 --no-pager`
  - `crictl ps` (install `cri-tools` if needed)

### Lab 04 — Control plane component tuning
- Goal: Modify static pod manifests for API server flags.
- Tasks:
  - Edit `/etc/kubernetes/manifests/kube-apiserver.yaml` to enable an admission plugin (e.g., `NamespaceLifecycle`).
  - Add audit logging flags to apiserver.
- Verify:
  - `kubectl get pods -n kube-system -w` (restarts)
  - `kubectl logs -n kube-system kube-apiserver-...`

### Lab 05 — etcd backup and restore
- Goal: Snapshot and restore etcd.
- Tasks:
  - Set env for etcdctl: `ETCDCTL_API=3` plus endpoints and certs from `/etc/kubernetes/pki/etcd`.
  - Snapshot: `etcdctl snapshot save /root/etcd-snap.db`.
  - Simulate issue; restore to new dir; update apiserver manifest `--etcd-*` paths if needed.
- Verify:
  - `etcdctl endpoint health`
  - Cluster resources intact after restore.

### Lab 06 — Certificates and kubeconfig
- Goal: Inspect, rotate, and validate certs.
- Tasks:
  - List `/etc/kubernetes/pki` and check expiry: `openssl x509 -in cert -text -noout`.
  - Run `kubeadm certs check-expiration` and `kubeadm certs renew all`.
  - Inspect kubeconfig files in `/etc/kubernetes/`.
- Verify: `kubectl get --raw='/livez'` and `kubectl get nodes`

### Lab 07 — Networking: CNI install & checks
- Goal: Deploy Calico (or Flannel) and validate pod-to-pod DNS.
- Tasks:
  - Apply CNI manifest.
  - Launch two busybox pods; verify cross-namespace ping and DNS to `kubernetes.default`.
- Verify:
  - `kubectl -n kube-system get pods -l k8s-app=kube-dns`
  - `kubectl exec -it bb -- nslookup kubernetes`

### Lab 08 — kube-proxy mode & CoreDNS troubleshooting
- Goal: Inspect kube-proxy (iptables/ipvs) and fix DNS issues.
- Tasks:
  - Check kube-proxy configmap.
  - Simulate CoreDNS crashloop (bad config), then fix.
- Verify: `kubectl get endpoints kube-dns -n kube-system`

### Lab 09 — Static pods
- Goal: Create and manage a static pod on the control-plane node.
- Tasks:
  - Place a pod manifest under `/etc/kubernetes/manifests/static-web.yaml`.
  - Confirm `NodeName` scheduling and lifecycle.
- Verify: `kubectl get pods -A -o wide | grep static-web`

---

## Workloads & Scheduling

### Lab 10 — Scheduling controls: taints, tolerations, affinity
- Goal: Steer pods to nodes correctly.
- Tasks:
  - Taint a worker: `kubectl taint nodes <node> role=spot:NoSchedule`.
  - Create a pod tolerating the taint.
  - Add `nodeSelector`, `nodeAffinity`, and inter-pod anti-affinity for `app=web`.
- Verify: `kubectl get pod -o wide`

### Lab 11 — Pod Priority & Preemption; PDB
- Goal: Keep critical workloads running.
- Tasks:
  - Create a `PriorityClass` and run a high-priority pod.
  - Define a `PodDisruptionBudget` for a deployment; attempt `drain`.
- Verify:
  - `kubectl describe pc <name>`
  - `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`

### Lab 12 — DaemonSets & node maintenance
- Goal: Deploy per-node agents and perform safe maintenance.
- Tasks:
  - Create a `DaemonSet` (e.g., node-exporter/netshoot).
  - Cordon/drain a node; observe DS behavior; uncordon.
- Verify: `kubectl get ds -A -o wide`

---

## Services & Networking

### Lab 13 — Services: ClusterIP/NodePort; Ingress
- Goal: Expose apps correctly.
- Tasks:
  - Create a `ClusterIP` and `NodePort` service for nginx.
  - Install ingress-nginx; create Ingress for `/v1` and `/v2` backends.
- Verify:
  - `kubectl get svc,ing -A`
  - Curl node IP for NodePort; curl Ingress host/path.

### Lab 14 — NetworkPolicy
- Goal: Isolate traffic and allow selectively.
- Tasks:
  - Apply default-deny ingress policy in a namespace.
  - Allow only pods labeled `role=frontend` to reach `api` on 80.
  - Allow DNS egress.
- Verify: Use busybox curl tests for success/fail paths.

---

## Storage

### Lab 15 — PV, PVC, StorageClass, access modes
- Goal: Use dynamic provisioning.
- Tasks:
  - Identify default `StorageClass`.
  - Create `PersistentVolumeClaim` and mount to a pod; write data; delete/recreate pod; validate persistence.
- Verify: `kubectl get sc,pv,pvc`

### Lab 16 — Expand PVC & StatefulSet with volumeClaimTemplates
- Goal: Manage persistent state at scale.
- Tasks:
  - Enable expansion on `StorageClass` if supported; expand PVC.
  - Create a `StatefulSet` with `volumeClaimTemplates`; verify stable identities.
- Verify: Data remains across restarts for same ordinal.

---

## Cluster Maintenance, Troubleshooting & Upgrades

### Lab 17 — Node/kubelet troubleshooting
- Goal: Recover a broken node.
- Tasks:
  - Stop kubelet, observe `NotReady`; start and analyze logs.
  - Fix a misconfigured cgroup driver or containerd socket.
- Verify: `kubectl get nodes`; `journalctl -u kubelet`

### Lab 18 — Control plane failures
- Goal: Diagnose API server and controller/scheduler issues.
- Tasks:
  - Break apiserver manifest (bad flag); observe; fix quickly.
  - Stop scheduler or controller-manager container; observe scheduling effects; restore.
- Verify: `kubectl get events --sort-by=.lastTimestamp | tail -n 20`

### Lab 19 — RBAC & authz
- Goal: Grant least-privilege access.
- Tasks:
  - Create `ClusterRole` and bind to `ServiceAccount` for read-only nodes.
  - Validate with `kubectl auth can-i` and impersonation.
- Verify: `kubectl auth can-i get nodes --as=system:serviceaccount:ns:sa`

### Lab 20 — Cluster upgrade (kubeadm)
- Goal: Upgrade control-plane and workers to v1.33.3.
- Tasks:
  - `kubeadm upgrade plan` then `kubeadm upgrade apply v1.33.3` on control-plane.
  - Upgrade kubelet/kubectl; restart kubelet.
  - Drain, upgrade, uncordon each worker.
- Verify:
  - `kubectl get nodes -o wide`
  - All control-plane components at target.

---

## Fast references & speed tips

- Context & namespace defaults
  ```bash
  kubectl config set-context --current --namespace=default
  alias k=kubectl
  ```
- Quick generators
  ```bash
  kubectl create deploy web --image=nginx:1.25 --dry-run=client -o yaml > web.yaml
  kubectl expose deploy web --port=80 --target-port=80 --type=ClusterIP --dry-run=client -o yaml > svc.yaml
  ```
- Rollouts & history
  ```bash
  kubectl set image deploy/web web=nginx:bad
  kubectl rollout status deploy/web
  kubectl rollout undo deploy/web
  ```
- Scheduling controls
  ```bash
  kubectl taint nodes node1 role=spot:NoSchedule
  kubectl cordon node1 && kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
  kubectl uncordon node1
  ```
- RBAC
  ```bash
  kubectl auth can-i get pods --as system:serviceaccount:ns:sa
  ```
- etcd snapshot (kubeadm-managed, local endpoint)
  ```bash
  export ETCDCTL_API=3
  export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
  export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
  export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
  etcdctl --endpoints=https://127.0.0.1:2379 snapshot save /root/etcd-snap.db
  etcdctl snapshot status /root/etcd-snap.db
  ```
- Certificate health
  ```bash
  kubeadm certs check-expiration
  ```

---

## Versioning note
- These labs pin to Kubernetes v1.33.3 for consistency. For exam realism, update to the exact exam version posted by the Linux Foundation and re-create your cluster accordingly (kubeadm images).

Reference certification page: `https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/`
