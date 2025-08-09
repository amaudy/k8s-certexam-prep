# Monitoring droplet for Prometheus and Grafana
resource "digitalocean_droplet" "monitoring" {
  name   = "monitoring-server"
  region = local.region
  size   = local.monitoring_size
  image  = local.image

  # Use SSH key ID from variable
  ssh_keys = [var.ssh_key_id]

  # Add monitoring tag for firewall rules
  tags = ["monitoring"]

  # Enhanced cloud-init for monitoring services setup
  user_data = <<-EOT
    #cloud-config
    package_update: true
    package_upgrade: true
    package_reboot_if_required: true
    
    # Install essential packages for monitoring stack
    packages:
      - curl
      - wget
      - htop
      - vim
      - git
      - ufw
      - snapd
    
    # Run commands after packages are installed
    runcmd:
      - echo "Monitoring server setup started at $(date)" >> /var/log/cloud-init-custom.log
      - systemctl enable ssh
      - systemctl start ssh
      - echo "Installing Docker via snap..." >> /var/log/cloud-init-custom.log
      - snap install docker
      - snap install docker-compose
      - echo "Docker installation completed at $(date)" >> /var/log/cloud-init-custom.log
      - mkdir -p /opt/monitoring/{prometheus,grafana,alertmanager}
      - chown -R root:root /opt/monitoring
      - echo "Starting monitoring stack..." >> /var/log/cloud-init-custom.log
      - cd /opt/monitoring && docker-compose up -d
      - echo "Monitoring stack setup completed at $(date)" >> /var/log/cloud-init-custom.log
      
    # Set timezone
    timezone: Asia/Singapore
    
    # Write docker-compose file for monitoring stack
    write_files:
      - path: /opt/monitoring/docker-compose.yml
        content: |
          version: '3.8'
          services:
            prometheus:
              image: prom/prometheus:latest
              container_name: prometheus
              ports:
                - "9090:9090"
              volumes:
                - ./prometheus:/etc/prometheus
                - prometheus_data:/prometheus
              command:
                - '--config.file=/etc/prometheus/prometheus.yml'
                - '--storage.tsdb.path=/prometheus'
                - '--web.console.libraries=/etc/prometheus/console_libraries'
                - '--web.console.templates=/etc/prometheus/consoles'
                - '--storage.tsdb.retention.time=200h'
                - '--web.enable-lifecycle'
              restart: unless-stopped
              
            grafana:
              image: grafana/grafana:latest
              container_name: grafana
              ports:
                - "3000:3000"
              volumes:
                - grafana_data:/var/lib/grafana
              environment:
                - GF_SECURITY_ADMIN_PASSWORD=admin123
                - GF_USERS_ALLOW_SIGN_UP=false
              restart: unless-stopped
              
            node-exporter:
              image: prom/node-exporter:latest
              container_name: node-exporter
              ports:
                - "9100:9100"
              volumes:
                - /proc:/host/proc:ro
                - /sys:/host/sys:ro
                - /:/rootfs:ro
              command:
                - '--path.procfs=/host/proc'
                - '--path.rootfs=/rootfs'
                - '--path.sysfs=/host/sys'
                - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
              restart: unless-stopped
              
          volumes:
            prometheus_data: {}
            grafana_data: {}
        permissions: '0644'
        
      - path: /opt/monitoring/prometheus/prometheus.yml
        content: |
          global:
            scrape_interval: 15s
            
          scrape_configs:
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']
                
            - job_name: 'node-exporter'
              static_configs:
                - targets: ['localhost:9100']
        permissions: '0644'
  EOT

  monitoring = true
  ipv6       = true
  backups    = false

  lifecycle {
    create_before_destroy = true
  }
}

# Monitoring server firewall - only accessible from caller IP
resource "digitalocean_firewall" "monitoring" {
  name = "monitoring-server-firewall"

  droplet_ids = [digitalocean_droplet.monitoring.id]

  # SSH access from caller IP only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # Grafana web interface - caller IP only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3000"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # Prometheus web interface - caller IP only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # Node Exporter metrics - caller IP only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9100"
    source_addresses = [local.caller_ipv4_cidr]
  }

  # Allow Kubernetes nodes to send metrics to Prometheus
  inbound_rule {
    protocol    = "tcp"
    port_range  = "9090"
    source_tags = ["k8s-node"]
  }

  # Allow Kubernetes nodes to expose metrics via Node Exporter
  inbound_rule {
    protocol    = "tcp"
    port_range  = "9100"
    source_tags = ["k8s-node"]
  }

  # ICMP for ping/traceroute from caller IP
  inbound_rule {
    protocol         = "icmp"
    source_addresses = [local.caller_ipv4_cidr]
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