### Kubernetes cluster setup with kubeadm (Ubuntu 22.04)

This guide provisions a single control-plane with workers using kubeadm and containerd.

### Prerequisites
- Ubuntu 22.04 on all nodes (1 control-plane, ≥1 worker)
- Root/sudo access and network connectivity between nodes
- Swap disabled on all nodes

### 1) Base OS prep (ALL nodes)
```bash
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

# Disable swap (required)
sudo swapoff -a
sudo sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab

# Kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl for networking
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

### 2) Install containerd (ALL nodes)
```bash
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo systemctl restart containerd
```

### 3) Install kubeadm, kubelet, kubectl (ALL nodes)
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### 4) Initialize control-plane (CONTROL-PLANE ONLY)
```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```
Save the printed join command.

Configure kubectl for your user:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5) Install CNI (control-plane)
Example Calico:
```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml
```

### 6) Join workers (EACH worker)
```bash
# Use the command printed by kubeadm init, e.g.
sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```
If needed, regenerate on control-plane:
```bash
kubeadm token create --print-join-command
```

### 7) Verify (control-plane)
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

### Common ports
- 6443/tcp to control-plane (API server)
- 10250/tcp intra-node (kubelet)
- 30000-32767/tcp NodePorts
- etcd (2379-2380/tcp), controller (10257/tcp), scheduler (10259/tcp)
- Overlay ports as required by CNI (e.g., 8472/udp for Flannel)

### Teardown
```bash
sudo kubeadm reset -f
sudo systemctl stop kubelet containerd
```
