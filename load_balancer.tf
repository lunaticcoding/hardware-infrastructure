# Hetzner Cloud Load Balancer for Ingress
resource "hcloud_load_balancer" "ingress" {
  name               = "${var.cluster_name}-ingress-lb"
  load_balancer_type = "lb11"
  location           = data.hcloud_location.this.name

  labels = {
    "cluster" = var.cluster_name
    "purpose" = "ingress"
  }
}

# Attach load balancer to the private network
resource "hcloud_load_balancer_network" "ingress" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  network_id       = hcloud_network.this.id
  ip               = cidrhost(hcloud_network_subnet.nodes.ip_range, 50)
}

# HTTP service (80 -> NodePort 30989)
resource "hcloud_load_balancer_service" "ingress_http" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  protocol         = "tcp"
  listen_port      = 80
  destination_port = 30989

  health_check {
    protocol = "http"
    port     = 30989
    http {
      path         = "/healthz"
      status_codes = ["200"]
    }
    interval = 15
    timeout  = 10
    retries  = 3
  }
}

# HTTPS service (443 -> NodePort 30489)
resource "hcloud_load_balancer_service" "ingress_https" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 30489

  health_check {
    protocol = "tcp"
    port     = 30489
    interval = 15
    timeout  = 10
    retries  = 3
  }
}

# ✅ Kube API service (6443 -> control plane 6443)
resource "hcloud_load_balancer_service" "kube_api" {
  load_balancer_id = hcloud_load_balancer.ingress.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443

  health_check {
    protocol = "tcp"
    port     = 6443
    interval = 10
    timeout  = 5
    retries  = 3
  }
}

# Target worker nodes (ingress NodePorts live on workers)
resource "hcloud_load_balancer_target" "worker_nodes" {
  for_each         = can(hcloud_server.workers) ? hcloud_server.workers : {}
  type             = "server"
  load_balancer_id = hcloud_load_balancer.ingress.id
  server_id        = each.value.id
  use_private_ip   = true

  depends_on = [
    hcloud_load_balancer_network.ingress
  ]
}

# Target control plane nodes (for 6443 kube API)
resource "hcloud_load_balancer_target" "control_plane_nodes" {
  for_each         = { for cp in local.control_planes : cp.name => cp }
  type             = "server"
  load_balancer_id = hcloud_load_balancer.ingress.id
  server_id        = hcloud_server.control_planes[each.key].id
  use_private_ip   = true

  depends_on = [
    hcloud_load_balancer_network.ingress
  ]
}

# Outputs
output "load_balancer_ip" {
  description = "Public IP of the ingress load balancer"
  value       = hcloud_load_balancer.ingress.ipv4
}

output "load_balancer_dns" {
  description = "DNS name of the ingress load balancer"
  value       = "lb-${hcloud_load_balancer.ingress.id}.hetzner-cloud.de"
}
