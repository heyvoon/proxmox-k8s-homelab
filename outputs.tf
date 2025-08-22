output "control_plane_ip" {
  description = "Control plane node IP address"
  value       = var.control_plane.ip
}

output "worker_node_ips" {
  description = "Worker node IP addresses"
  value       = [for node in var.worker_nodes : node.ip]
}

output "kubernetes_dashboard_url" {
  description = "Kubernetes Dashboard URL"
  value       = "https://${var.control_plane.ip}:6443"
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://argocd.${var.control_plane.ip}.nip.io"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "https://grafana.${var.control_plane.ip}.nip.io"
}

output "portainer_url" {
  description = "Portainer URL"
  value       = "https://portainer.${var.control_plane.ip}.nip.io"
}

output "cluster_access_command" {
  description = "Command to access the cluster"
  value       = "ssh -i ${var.ssh_private_key_path} dev@${var.control_plane.ip}"
}

output "application_credentials" {
  description = "Application credentials"
  value = {
    argocd_admin_user    = "admin"
    grafana_admin_user   = "admin"
    portainer_admin_user = "admin"
  }
  sensitive = false
}