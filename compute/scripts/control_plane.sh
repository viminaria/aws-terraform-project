#cloud-config
bootcmd:
  - test -f /swapfile || (fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile)
  - grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab

users:
  - name: ubuntu
    ssh_authorized_keys:
      - ${ssh_public_key}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']

runcmd:
  - curl -sfL https://get.k3s.io | sh -s - server --token "${k3s_token}" --write-kubeconfig-mode 644 --cluster-init || true
