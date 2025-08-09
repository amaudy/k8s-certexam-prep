output "droplet_names" {
  description = "Names of created droplets"
  value       = [for d in digitalocean_droplet.nodes : d.name]
}

output "droplet_ipv4_addresses" {
  description = "Public IPv4 addresses of created droplets"
  value       = [for d in digitalocean_droplet.nodes : d.ipv4_address]
}

output "droplet_ipv6_addresses" {
  description = "Public IPv6 addresses of created droplets"
  value       = [for d in digitalocean_droplet.nodes : d.ipv6_address]
}

# Monitoring server outputs
output "monitoring_server_name" {
  description = "Name of the monitoring server"
  value       = digitalocean_droplet.monitoring.name
}

output "monitoring_server_ipv4" {
  description = "Public IPv4 address of monitoring server"
  value       = digitalocean_droplet.monitoring.ipv4_address
}

output "monitoring_server_ipv6" {
  description = "Public IPv6 address of monitoring server"
  value       = digitalocean_droplet.monitoring.ipv6_address
}

output "grafana_url" {
  description = "Grafana web interface URL"
  value       = "http://${digitalocean_droplet.monitoring.ipv4_address}:3000"
}

output "prometheus_url" {
  description = "Prometheus web interface URL"
  value       = "http://${digitalocean_droplet.monitoring.ipv4_address}:9090"
}


