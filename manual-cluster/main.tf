locals {
  droplet_count = 3
  region        = "sgp1"
  image         = "ubuntu-22-04-x64"
  size          = "s-1vcpu-2gb" # Adjust as needed
  ssh_key_names = []             # Optionally set to match your DO account SSH key names
}

data "digitalocean_ssh_keys" "all" {}

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

  # Attach all account SSH keys unless overridden
  ssh_keys = length(local.ssh_key_names) > 0 ? [for k in data.digitalocean_ssh_keys.all.ssh_keys : k.fingerprint if contains(local.ssh_key_names, k.name)] : [for k in data.digitalocean_ssh_keys.all.ssh_keys : k.fingerprint]

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

resource "digitalocean_firewall" "ssh_web" {
  name = "manual-cluster-allow-ssh"

  droplet_ids = [for d in digitalocean_droplet.nodes : d.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "0"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "0"
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


