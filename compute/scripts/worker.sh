#cloud-config
bootcmd:
  - fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab

users:
  - name: ubuntu
    ssh_authorized_keys:
      - ${ssh_public_key}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']

runcmd:
  - curl -sfL https://get.k3s.io | sh -s - agent --token "${k3s_token}" --server https://${k3s_control_plane_ip}:6443
