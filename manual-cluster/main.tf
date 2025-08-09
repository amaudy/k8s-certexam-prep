locals {
  droplet_count = 3
  region        = "sgp1"
  image         = "ubuntu-22-04-x64"
  size          = "s-1vcpu-2gb" # Adjust as needed
}

# Discover caller public IPv4 address automatically
data "http" "ip_echo" {
  url = "https://api.ipify.org?format=text"
}

locals {
  caller_ipv4_cidr = "${trimspace(data.http.ip_echo.response_body)}/32"
}

resource "digitalocean_project" "cluster" {
  name        = "manual-cluster"
  description = "Project for manual cluster droplets"
  purpose     = "Web Application"
  environment = "Production"
}

resource "digitalocean_droplet" "nodes" {
  count  = local.droplet_count
  name   = "manual-node-${count.index + 1}"
  region = local.region
  size   = local.size
  image  = local.image

  # Use SSH key ID from variable
  ssh_keys = [var.ssh_key_id]

  # Add k8s-node tag for firewall rules
  tags = ["k8s-node"]

  # Basic cloud-init to ensure packages are up to date
  user_data = <<-EOT
    #cloud-config
    package_update: true
    package_upgrade: true
  EOT

  monitoring = true
  ipv6       = true
  backups    = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_firewall" "kubernetes_cluster" {
  name = "kubernetes-cluster-firewall"

  droplet_ids = [for d in digitalocean_droplet.nodes : d.id]

  # SSH access from caller IP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # Kubernetes API server access from caller IP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "6443"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # HTTP/HTTPS access from caller IP (for applications)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = [local.caller_ipv4_cidr]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # NodePort services access from caller IP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "30000-32767"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # Inter-node communication - Kubernetes API server
  inbound_rule {
    protocol    = "tcp"
    port_range  = "6443"
    source_tags = ["k8s-node"]
  }

  # Inter-node communication - etcd server client API
  inbound_rule {
    protocol    = "tcp"
    port_range  = "2379-2380"
    source_tags = ["k8s-node"]
  }

  # Inter-node communication - Kubelet API
  inbound_rule {
    protocol    = "tcp"
    port_range  = "10250"
    source_tags = ["k8s-node"]
  }

  # Inter-node communication - kube-scheduler
  inbound_rule {
    protocol    = "tcp"
    port_range  = "10259"
    source_tags = ["k8s-node"]
  }

  # Inter-node communication - kube-controller-manager
  inbound_rule {
    protocol    = "tcp"
    port_range  = "10257"
    source_tags = ["k8s-node"]
  }

  # Inter-node communication - Container Network Interface (CNI)
  inbound_rule {
    protocol    = "tcp"
    port_range  = "179"
    source_tags = ["k8s-node"]
  }

  # Inter-node communication - VXLAN (Flannel)
  inbound_rule {
    protocol    = "udp"
    port_range  = "4789"
    source_tags = ["k8s-node"]
  }

  # Inter-node communication - Calico BGP
  inbound_rule {
    protocol    = "tcp"
    port_range  = "179"
    source_tags = ["k8s-node"]
  }

  # Inter-node communication - Calico VXLAN
  inbound_rule {
    protocol    = "udp"
    port_range  = "4789"
    source_tags = ["k8s-node"]
  }

  # ICMP for ping/traceroute from caller IP
  inbound_rule {
    protocol         = "icmp"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # Inter-node ICMP
  inbound_rule {
    protocol    = "icmp"
    source_tags = ["k8s-node"]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_project_resources" "attach" {
  project = digitalocean_project.cluster.id
  resources = [
    for d in digitalocean_droplet.nodes : d.urn
  ]
}

output "droplet_ips" {
  description = "Public IPv4 addresses of droplets"
  value       = [for d in digitalocean_droplet.nodes : d.ipv4_address]
}


