all:
  children:
    masters:
      hosts:
        ${control_plane_name}:
          ansible_host: ${control_plane_ip}
          node_role: master
    workers:
      hosts:
%{for node in worker_nodes}
        ${node.name}:
          ansible_host: ${node.ip}
          node_role: worker
%{endfor}
  vars:
    ansible_user: ${ssh_user}
    ansible_ssh_private_key_file: ${ssh_private_key}
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
