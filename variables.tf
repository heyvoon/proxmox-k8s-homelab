variable "proxmox_api_token" {
  description = "Proxmox API token in the format user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_api_url" {
  description = "URL of the Proxmox API"
  type        = string
}

variable "proxmox_password" {
  description = "Password for root@pam"
  type        = string
  sensitive   = true
}

variable "proxmox_pve_ip" {
  description = "Proxmox node IP address"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for dev user"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for cluster management"
  type        = string
  default     = "/home/dev/.ssh/id_rsa"
}

variable "template_name" {
  description = "Name of the VM template"
  type        = string
  default     = "ubuntu-2404-template"
}

variable "storage_pool" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-zfs"
}

variable "bridge_name" {
  description = "Network bridge name"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.1.1"
}

variable "network_cidr" {
  description = "Network CIDR"
  type        = string
  default     = "24"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "metallb_ip_range" {
  description = "MetalLB IP range for LoadBalancer services"
  type        = string
  default     = "192.168.1.240-192.168.1.250"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29.10"
}

# Node configurations
variable "control_plane" {
  description = "Control plane node configuration"
  type = object({
    name   = string
    vmid   = number
    ip     = string
    cores  = number
    memory = number
    disk   = string
  })
  default = {
    name   = "k8s-cp-01"
    vmid   = 4001
    ip     = "192.168.1.101"
    cores  = 1
    memory = 2048
    disk   = "32G"
  }
}

variable "worker_nodes" {
  description = "Worker nodes configuration"
  type = list(object({
    name   = string
    vmid   = number
    ip     = string
    cores  = number
    memory = number
    disk   = string
  }))
  default = [
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
}

variable "application_passwords" {
  description = "Application passwords"
  type = object({
    argocd_admin    = string
    grafana_admin   = string
    portainer_admin = string
  })
  sensitive = true
  default = {
    argocd_admin    = "changeme123!"
    grafana_admin   = "changeme123!"
    portainer_admin = "changeme123!"
  }
}