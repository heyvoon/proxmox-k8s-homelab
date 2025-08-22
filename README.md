# Proxmox Kubernetes Cluster with Terraform

This project deploys a production-ready Kubernetes cluster on Proxmox VE using Terraform and Ansible.

## Architecture

- **1x Control Plane Node**: k8s-cp-01 (1 core, 2GB RAM, 32GB disk)
- **3x Worker Nodes**: k8s-worker-01/02/03 (1 core, 2GB RAM, 32GB disk each)

## Prerequisites

1. **Proxmox VE** with API token configured
2. **Ubuntu 24.04 Server Cloud Image** template in Proxmox
3. **Terraform** >= 1.0
4. **Ansible** >= 2.9
5. **SSH key pair** for authentication

## Setup Instructions

### 1. Prepare Proxmox Template

```bash
# Download Ubuntu 24.04 cloud image
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img

# Create VM template in Proxmox
qm create 9000 --name ubuntu-24.04-server-cloudimg --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 ubuntu-24.04-server-cloudimg-amd64.img local-zfs
qm set 9000 --scsihw virtio-scsi-pci --virtio0 local-zfs:vm-9000-disk-0
qm set 9000 --boot c --bootdisk virtio0
qm set 9000 --ide2 local-zfs:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

### 2. Configure Terraform Variables

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings
vim terraform.tfvars
```

### 3. Install Ansible Requirements

```bash
cd ansible
ansible-galaxy install -r requirements.yml
```

### 4. Deploy the Cluster

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy cluster
terraform apply
```

## Deployed Applications

The cluster includes the following applications accessible via Ingress:

- **ArgoCD**: GitOps continuous deployment
- **Grafana**: Monitoring dashboards
- **Prometheus**: Metrics collection
- **Portainer**: Container management UI
- **Loki**: Log aggregation

## Access URLs

After deployment, access applications via:

- ArgoCD: `https://argocd.<control-plane-ip>.nip.io`
- Grafana: `https://grafana.<control-plane-ip>.nip.io`
- Portainer: `https://portainer.<control-plane-ip>.nip.io`

## Cluster Management

### SSH to Control Plane

```bash
ssh -i /home/dev/.ssh/id_rsa dev@<control-plane-ip>
```

### kubectl Commands

```bash
# Get cluster nodes
kubectl get nodes

# Get all pods
kubectl get pods -A

# Get services
kubectl get svc -A
```

## Monitoring and Logging

### Grafana Dashboards

- Kubernetes cluster metrics
- Node resource usage
- Pod performance
- Application metrics

### Log Aggregation

- Centralized logging with Loki
- Application and system logs
- Integration with Grafana for log visualization

## Customization

### Scaling Worker Nodes

Edit `terraform.tfvars` to add/remove worker nodes:

```hcl
worker_nodes = [
  # Add more worker nodes as needed
  {
    name   = "k8s-worker-04"
    vmid   = 4005
    ip     = "192.168.1.105"
    cores  = 1
    memory = 2048
    disk   = "32G"
  }
]
```

### Resource Adjustments

Modify node specifications in `terraform.tfvars`:

```hcl
control_plane = {
  name   = "k8s-cp-01"
  vmid   = 4001
  ip     = "192.168.1.101"
  cores  = 2      # Increase cores
  memory = 4096   # Increase memory
  disk   = "50G"  # Increase disk
}
```

## Troubleshooting

### Common Issues

1. **Template not found**: Ensure Ubuntu cloud image template exists in Proxmox
2. **Network connectivity**: Verify bridge configuration and IP ranges
3. **SSH access**: Check SSH keys and cloud-init configuration
4. **Cluster not ready**: Verify containerd and kubelet services

### Debug Commands

```bash
# Check Terraform state
terraform show

# Validate Ansible inventory
ansible-inventory -i ansible/inventory.yml --list

# Test SSH connectivity
ansible all -i ansible/inventory.yml -m ping

# Check cluster status
kubectl cluster-info
kubectl get componentstatuses
```

## Security Considerations

- SSH key-based authentication only
- No password-based sudo access
- Network policies via Cilium
- TLS encryption for all web interfaces
- Secrets management via Kubernetes secrets

## Maintenance

### Updates

```bash
# Update Terraform modules
terraform init -upgrade

# Update Ansible collections
ansible-galaxy install -r ansible/requirements.yml --force

# Update Kubernetes components
# (Handled via Ansible playbook updates)
```

### Backup

```bash
# Backup etcd
kubectl -n kube-system exec etcd-k8s-cp-01 -- \
  etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  snapshot save /tmp/etcd-snapshot.db
```

## License

This project is licensed under the MIT License.