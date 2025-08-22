# Installation Guide

This guide walks you through deploying a production-ready Kubernetes cluster on Proxmox VE using Terraform and Ansible.

## 📋 Prerequisites

- **Proxmox VE** 7.0+ with API access
- **Terraform** >= 1.0
- **Ansible** >= 2.9
- **Linux/macOS** workstation (Ubuntu/Debian recommended)
- **SSH key pair** for authentication
- **Network access** to Proxmox and target IP range

## 🛠️ Step 1: Install Required Tools

### On Ubuntu/Debian:
```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install Ansible
sudo apt update
sudo apt install ansible

# Install additional tools
sudo apt install openssh-client netcat-traditional git curl
```

### On macOS:
```bash
# Install via Homebrew
brew install terraform ansible openssh git curl
```

## 🏗️ Step 2: Prepare Proxmox Environment

### 2.1 Create Ubuntu 24.04 Template

SSH to your Proxmox host and run:

```bash
# Download Ubuntu cloud image
cd /var/lib/vz/template/iso/
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img

# Create VM template (adjust storage if needed)
qm create 9000 --name ubuntu-24.04-server-cloudimg --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 ubuntu-24.04-server-cloudimg-amd64.img local-zfs
qm set 9000 --scsihw virtio-scsi-pci --virtio0 local-zfs:vm-9000-disk-0
qm set 9000 --boot c --bootdisk virtio0
qm set 9000 --ide2 local-zfs:cloudinit
qm set 9000 --serial0 socket --vga serial0

# Convert to template
qm template 9000
```

### 2.2 Create Proxmox API Token

1. Open Proxmox web UI
2. Navigate to **Datacenter** → **Permissions** → **API Tokens**
3. Click **Add** and create:
   - **Token ID**: `terraform@pve!terraform`
   - **Privilege Separation**: Unchecked
4. **Copy the token secret** - you'll need it later
5. Ensure the `terraform@pve` user has appropriate permissions

### 2.3 Configure Network Bridge (if needed)

Ensure you have a bridge configured for Kubernetes networking:
```bash
# Check existing bridges
ip link show | grep vmbr

# If vmbr1 doesn't exist, create it in Proxmox UI:
# System → Network → Create → Linux Bridge
```

## 📁 Step 3: Project Setup

```bash
# Clone or create project directory
mkdir proxmox-k8s-homelab
cd proxmox-k8s-homelab

# Create directory structure
mkdir -p templates
mkdir -p ansible/{roles/{common,containerd,kubernetes,control-plane,worker-nodes,cni,applications}/tasks,group_vars}

# Copy all project files to their respective locations
# (Download files from the provided artifacts)
```

## 🔐 Step 4: Generate SSH Keys

```bash
# Generate dedicated SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/proxmox-k8s -N ""

# Add to SSH agent
ssh-add ~/.ssh/proxmox-k8s

# Get public key content (you'll need this)
cat ~/.ssh/proxmox-k8s.pub
```

## ⚙️ Step 5: Configure Deployment

### 5.1 Create Terraform Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings
vim terraform.tfvars
```

### 5.2 Update Configuration

Edit `terraform.tfvars` with your environment details:

```hcl
# Proxmox Configuration
proxmox_api_url          = "https://YOUR-PROXMOX-IP:8006/api2/json"
proxmox_api_token_id     = "terraform@pve!terraform"
proxmox_api_token_secret = "YOUR-ACTUAL-TOKEN-SECRET"
proxmox_node            = "YOUR-PROXMOX-NODE-NAME"

# SSH Configuration
ssh_public_key       = "ssh-rsa AAAAB3NzaC1yc2E... YOUR-PUBLIC-KEY"
ssh_private_key_path = "~/.ssh/proxmox-k8s"

# Network Configuration (ADJUST TO YOUR NETWORK!)
bridge_name      = "vmbr0"
network_gateway  = "192.168.1.1"
network_cidr     = "24"
dns_servers      = ["8.8.8.8", "8.8.4.4"]
metallb_ip_range = "192.168.1.240-192.168.1.250"

# Storage
storage_pool = "local-zfs"  # or "local-zfs"

# Node Configuration (ADJUST IPs TO YOUR NETWORK!)
control_plane = {
  name   = "k8s-cp-01"
  vmid   = 4001
  ip     = "192.168.1.101"
  cores  = 1
  memory = 2048
  disk   = "32G"
}

worker_nodes = [
  {
    name   = "k8s-worker-01"
    vmid   = 4002
    ip     = "192.168.1.102"
    cores  = 1
    memory = 2048
    disk   = "32G"
  },
  {
    name   = "k8s-worker-02"
    vmid   = 4003
    ip     = "192.168.1.103"
    cores  = 1
    memory = 2048
    disk   = "32G"
  },
  {
    name   = "k8s-worker-03"
    vmid   = 4004
    ip     = "192.168.1.104"
    cores  = 1
    memory = 2048
    disk   = "32G"
  }
]

# Application Passwords (CHANGE THESE!)
application_passwords = {
  argocd_admin    = "MySecurePassword123!"
  grafana_admin   = "MySecurePassword123!"
  portainer_admin = "MySecurePassword123!"
}
```

### 5.3 Install Ansible Dependencies

```bash
cd ansible
ansible-galaxy collection install kubernetes.core
cd ..
```

## 🚀 Step 6: Deploy the Stack

### 6.1 Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init

# Validate configuration
terraform validate
```

### 6.2 Plan Deployment

```bash
# Review what will be created
terraform plan
```

### 6.3 Deploy Everything

```bash
# Deploy the complete stack
terraform apply

# When prompted, type 'yes' to confirm
```

**⏱️ Deployment Time**: Approximately 15-20 minutes

The deployment process will:
1. ✅ Create 4 VMs in Proxmox
2. ✅ Configure cloud-init and networking
3. ✅ Install containerd and Kubernetes
4. ✅ Initialize the control plane
5. ✅ Join worker nodes to cluster
6. ✅ Deploy CNI (Cilium)
7. ✅ Install application stack
8. ✅ Configure ingress and monitoring

## ✅ Step 7: Verify Deployment

### 7.1 Check Terraform Output

```bash
# View deployment results
terraform output

# Check state
terraform show
```

### 7.2 Access the Cluster

```bash
# SSH to control plane
ssh -i ~/.ssh/proxmox-k8s dev@192.168.1.101

# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

### 7.3 Test Applications

Access your applications via web browser:

- **ArgoCD**: https://argocd.192.168.1.101.nip.io
- **Grafana**: https://grafana.192.168.1.101.nip.io (admin/your-password)
- **Portainer**: https://portainer.192.168.1.101.nip.io  
- **Prometheus**: https://prometheus.192.168.1.101.nip.io

## 🎯 Step 8: Post-Installation

### 8.1 Save Important Information

```bash
# Save cluster access info
echo "Cluster Access:" > cluster-info.txt
echo "SSH: ssh -i ~/.ssh/proxmox-k8s dev@192.168.1.101" >> cluster-info.txt
echo "ArgoCD: https://argocd.192.168.1.101.nip.io" >> cluster-info.txt
echo "Grafana: https://grafana.192.168.1.101.nip.io" >> cluster-info.txt

# Save ArgoCD admin password (if generated)
cat ansible/argocd_admin_password.txt
```

### 8.2 Configure kubectl Locally (Optional)

```bash
# Copy kubeconfig from control plane
scp -i ~/.ssh/proxmox-k8s dev@192.168.1.101:~/.kube/config ~/.kube/config-proxmox-k8s

# Use the config
export KUBECONFIG=~/.kube/config-proxmox-k8s
kubectl get nodes
```

## 🛠️ Using the Makefile

For easier management, use the included Makefile:

```bash
make help     # Show available commands
make init     # Initialize Terraform  
make plan     # Plan deployment
make apply    # Deploy stack
make check    # Verify cluster status
make destroy  # Destroy everything
make clean    # Clean temporary files
```

## 🔧 Troubleshooting

### Common Issues

**1. Template not found:**
```bash
# Verify template exists
qm list | grep ubuntu-24.04
```

**2. Network connectivity issues:**
```bash
# Test connectivity
ping 192.168.1.101

# Check SSH access
ssh -i ~/.ssh/proxmox-k8s dev@192.168.1.101
```

**3. Ansible connectivity:**
```bash
cd ansible
ansible all -i inventory.yml -m ping
```

**4. Cluster not ready:**
```bash
# Check kubelet status
ssh -i ~/.ssh/proxmox-k8s dev@192.168.1.101
sudo systemctl status kubelet
sudo journalctl -u kubelet -f
```

### Debug Commands

```bash
# Terraform debug
export TF_LOG=DEBUG
terraform apply

# Check VM status in Proxmox
qm status 4001
qm status 4002
qm status 4003
qm status 4004

# Manual cluster check
kubectl get componentstatuses
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 🔄 Scaling and Updates

### Add Worker Nodes

Edit `terraform.tfvars` and add more worker nodes:
```hcl
worker_nodes = [
  # existing nodes...
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

Then run:
```bash
terraform plan
terraform apply
```

### Update Resources

Modify node specifications in `terraform.tfvars` and apply changes:
```bash
terraform apply
```

## 🧹 Cleanup

To destroy the entire stack:

```bash
terraform destroy
# Type 'yes' when prompted
```

## 📚 Next Steps

1. **Deploy Applications**: Use ArgoCD to deploy your applications
2. **Configure Monitoring**: Set up custom Grafana dashboards
3. **Setup Backups**: Configure etcd backups
4. **Security Hardening**: Implement network policies and RBAC
5. **CI/CD Integration**: Connect your Git repositories to ArgoCD

---

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review Terraform and Ansible logs
3. Verify network connectivity and firewall settings
4. Ensure all prerequisites are met

**Happy clustering!** 🚀