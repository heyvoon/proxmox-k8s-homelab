# Fixed provider block - uses PAM user for snippet upload
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  username  = "root@pam"
  password  = var.proxmox_password
  insecure  = true

  ssh {
    agent    = true
    username = "root"
    node {
      name    = "proxmox"
      address = var.proxmox_pve_ip
    }
  }
}

# Generate cloud-init user data
locals {
  user_data = templatefile("${path.module}/templates/user-data.yaml.tpl", {
    ssh_public_key = var.ssh_public_key
    dns_servers    = join(",", var.dns_servers)
  })
}

# Data source to find the template - MOVED BEFORE USAGE
data "proxmox_virtual_environment_vms" "template" {
  node_name = var.proxmox_node

  filter {
    name   = "name"
    values = [var.template_name]
  }
}

# Upload cloud-init configuration - MOVED BEFORE VM CREATION
resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "usb-storage-01" # Adjust to your storage pool
  node_name    = var.proxmox_node

  source_raw {
    data      = local.user_data
    file_name = "k8s-cloud-init.yaml"
  }
}

# Create control plane node
resource "proxmox_virtual_environment_vm" "control_plane" {
  name        = var.control_plane.name
  description = "Kubernetes Control Plane Node"
  node_name   = var.proxmox_node
  vm_id       = var.control_plane.vmid
  tags        = ["kubernetes", "control-plane"]

  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
    datastore_id = var.storage_pool
  }

  cpu {
    cores   = var.control_plane.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.control_plane.memory
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "virtio0"
    size         = parseint(regex("(\\d+)", var.control_plane.disk)[0], 10)
  }

  network_device {
    bridge = var.bridge_name
    model  = "virtio"
  }

  initialization {
    datastore_id = var.storage_pool
    ip_config {
      ipv4 {
        address = "${var.control_plane.ip}/${var.network_cidr}"
        gateway = var.network_gateway
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_data_file_id,
    ]
  }

  # ADDED: Ensure VM is started
  started = true
}

# Create worker nodes
resource "proxmox_virtual_environment_vm" "worker_nodes" {
  count = length(var.worker_nodes)
  
  name        = var.worker_nodes[count.index].name
  description = "Kubernetes Worker Node ${count.index + 1}"
  node_name   = var.proxmox_node
  vm_id       = var.worker_nodes[count.index].vmid
  tags        = ["kubernetes", "worker"]

  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
    datastore_id = var.storage_pool
  }

  cpu {
    cores   = var.worker_nodes[count.index].cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.worker_nodes[count.index].memory
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "virtio0"
    size         = parseint(regex("(\\d+)", var.worker_nodes[count.index].disk)[0], 10)
  }

  network_device {
    bridge = var.bridge_name
    model  = "virtio"
  }

  initialization {
    datastore_id = var.storage_pool
    ip_config {
      ipv4 {
        address = "${var.worker_nodes[count.index].ip}/${var.network_cidr}"
        gateway = var.network_gateway
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_data_file_id,
    ]
  }

  # ADDED: Ensure VM is started
  started = true
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.yml.tpl", {
    control_plane_ip   = var.control_plane.ip
    control_plane_name = var.control_plane.name
    worker_nodes       = var.worker_nodes
    ssh_user           = "dev"
    ssh_private_key    = var.ssh_private_key_path
  })
  filename = "${path.module}/ansible/inventory.yml"

  depends_on = [
    proxmox_virtual_environment_vm.control_plane,
    proxmox_virtual_environment_vm.worker_nodes
  ]
}

# Generate Ansible variables
resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/group_vars.yml.tpl", {
    kubernetes_version       = var.kubernetes_version
    metallb_ip_range        = var.metallb_ip_range
    argocd_admin_password   = var.application_passwords.argocd_admin
    grafana_admin_password  = var.application_passwords.grafana_admin
    portainer_admin_password = var.application_passwords.portainer_admin
    control_plane_ip        = var.control_plane.ip
  })
  filename = "${path.module}/ansible/group_vars/all.yml"

  depends_on = [
    proxmox_virtual_environment_vm.control_plane,
    proxmox_virtual_environment_vm.worker_nodes
  ]
}

# IMPROVED: Better wait logic with retry mechanism
resource "null_resource" "wait_for_vms" {
  provisioner "local-exec" {
    working_dir = "${path.module}/ansible"
    command = <<-EOT
      echo "Waiting for VMs to be ready..."
      for ip in ${var.control_plane.ip} ${join(" ", [for node in var.worker_nodes : node.ip])}; do
        echo "Waiting for $ip to be ready..."
        max_attempts=60
        attempt=0
        while [ $attempt -lt $max_attempts ]; do
          if nc -z -w5 $ip 22; then
            echo "$ip is ready!"
            break
          fi
          attempt=$((attempt + 1))
          echo "Attempt $attempt/$max_attempts failed, retrying in 10 seconds..."
          sleep 10
        done
        if [ $attempt -eq $max_attempts ]; then
          echo "ERROR: $ip failed to become ready after $max_attempts attempts"
          exit 1
        fi
      done
      echo "All VMs are ready!"
    EOT
  }

  depends_on = [
    proxmox_virtual_environment_vm.control_plane,
    proxmox_virtual_environment_vm.worker_nodes
  ]
}

# IMPROVED: Better Ansible execution with error handling
resource "null_resource" "deploy_kubernetes" {
  provisioner "local-exec" {
    working_dir = "${path.module}/ansible"
    command = <<-EOT
      echo "Starting Kubernetes deployment..."
      
      # Check if inventory exists
      if [ ! -f inventory.yml ]; then
        echo "ERROR: inventory.yml not found"
        exit 1
      fi
      
      # Test connectivity first
      echo "Testing Ansible connectivity..."
      ansible all -i inventory.yml -m ping --timeout=30
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Ansible connectivity test failed"
        exit 1
      fi
      
      # Run the playbook
      echo "Running Ansible playbook..."
      ansible-playbook -i inventory.yml site.yml -v
      
      if [ $? -ne 0 ]; then
        echo "ERROR: Ansible playbook execution failed"
        exit 1
      fi
      
      echo "Kubernetes deployment completed successfully!"
    EOT
  }

  depends_on = [
    local_file.ansible_inventory,
    local_file.ansible_vars,
    null_resource.wait_for_vms
  ]
}

# IMPROVED: Resilient cluster validation with retries and kubeconfig fallback
resource "null_resource" "validate_cluster" {
  provisioner "local-exec" {
    working_dir = "${path.module}/ansible"
    command = <<-EOT
      set -euo pipefail

      echo "Validating Kubernetes cluster..."

      CP_IP="${var.control_plane.ip}"
      SSH_KEY="${var.ssh_private_key_path}"
      SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${var.ssh_private_key_path}"
      REMOTE="dev@${var.control_plane.ip}"

      # Remove stale host key (CP may have been rebuilt)
      ssh-keygen -R "${var.control_plane.ip}" >/dev/null 2>&1 || true

      # Small initial settle time
      sleep 15

      # Helper: run kubectl remotely with sane fallbacks
      rk() {
        ssh $SSH_OPTS $REMOTE "kubectl \"\$@\" 2>/dev/null || sudo -E /usr/bin/kubectl --kubeconfig /etc/kubernetes/admin.conf \"\$@\""
      }

      echo "Waiting for API server to respond and nodes to register..."
      # Try up to ~5 minutes (30 * 10s)
      ATTEMPTS=30
      i=0
      until rk get nodes -o wide >/dev/null 2>&1; do
        i=$((i+1))
        if [ "$i" -ge "$ATTEMPTS" ]; then
          echo "ERROR: API not responding to kubectl on control plane."
          echo "Diagnostics:"
          ssh $SSH_OPTS $REMOTE 'systemctl --no-pager --full status kubelet || true'
          ssh $SSH_OPTS $REMOTE 'sudo journalctl -u kubelet --no-pager -n 100 || true'
          exit 1
        fi
        sleep 10
      done

      echo "Checking cluster nodes..."
      rk get nodes -o wide

      echo "Waiting for all nodes to be Ready..."
      READY_ATTEMPTS=30
      j=0
      until rk get nodes --no-headers | awk '{print $2}' | grep -qE '(^|,)Ready(,|$)'; do
        j=$((j+1))
        if [ "$j" -ge "$READY_ATTEMPTS" ]; then
          echo "ERROR: Nodes not Ready within timeout."
          rk get nodes -o wide || true
          rk get pods -A -o wide || true
          exit 1
        fi
        sleep 10
      done

      echo "Checking control-plane components..."
      rk get pods -n kube-system -o wide

      echo "Checking cluster info..."
      rk cluster-info

      echo "Cluster validation completed!"
    EOT
  }

  # If you want this to re-run on each apply when CP IP or SSH key changes:
  triggers = {
    cp_ip  = var.control_plane.ip
    sshkey = var.ssh_private_key_path
  }

  depends_on = [null_resource.deploy_kubernetes]
}
