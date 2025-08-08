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


