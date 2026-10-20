#cloud-config
bootcmd:
  - fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab

write_files:
  - path: /etc/profile.d/k3s.sh
    content: |
      #!/bin/bash
      curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644 --disable traefik --cluster-init
      echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+no+9tNGnJppqUmdUWMjhdDYjvexW6glfHoEOIGfFY viminaria@nixos' >> /home/ubuntu/.ssh/authorized_keys
      chown -R ubuntu:ubuntu /home/ubuntu/.ssh
      chmod 700 /home/ubuntu/.ssh
      chmod 600 /home/ubuntu/.ssh/authorized_keys

runcmd:
  - bash /etc/profile.d/k3s.sh

ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+no+9tNGnJppqUmdUWMjhdDYjvexW6glfHoEOIGfFY viminaria@nixos
