# Kubernetes Configuration
kubernetes_version: "${kubernetes_version}"
kubeadm_version: "${kubernetes_version}-1.1"
kubectl_version: "${kubernetes_version}-1.1"
kubelet_version: "${kubernetes_version}-1.1"

# Container Runtime
containerd_version: "1.7.13"

# Network Configuration
pod_network_cidr: "10.244.0.0/16"
service_network_cidr: "10.96.0.0/12"
control_plane_endpoint: "${control_plane_ip}:6443"

# CNI Configuration
cni_plugin: "cilium"

# MetalLB Configuration
metallb_ip_range: "${metallb_ip_range}"

# Application Passwords
argocd_admin_password: "${argocd_admin_password}"
grafana_admin_password: "${grafana_admin_password}"
portainer_admin_password: "${portainer_admin_password}"

# Helm Configuration
helm_version: "3.14.0"