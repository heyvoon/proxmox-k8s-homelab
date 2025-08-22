#cloud-config
users:
  - name: dev
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/dev
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ${ssh_public_key}

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - software-properties-common
  - htop
  - vim
  - git
  - unzip

# Disable password authentication
ssh_pwauth: false

# Configure SSH
ssh_config:
  PasswordAuthentication: no
  PubkeyAuthentication: yes
  PermitRootLogin: no

# Configure DNS
manage_resolv_conf: true
resolv_conf:
  nameservers:
%{for dns in split(",", dns_servers)}
    - ${dns}
%{endfor}

runcmd:
  # Ensure SSH service is running
  - systemctl enable ssh
  - systemctl start ssh
  
  # Configure kernel modules for Kubernetes
  - echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
  - echo 'overlay' >> /etc/modules-load.d/k8s.conf
  - modprobe br_netfilter
  - modprobe overlay
  
  # Configure sysctl for Kubernetes
  - echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf
  - echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf
  - echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/k8s.conf
  - sysctl --system
  
  # Disable swap
  - swapoff -a
  - sed -i '/swap/d' /etc/fstab

final_message: "Cloud-init setup complete. System ready for Kubernetes installation."
