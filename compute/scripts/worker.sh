#cloud-config
bootcmd:
  - fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab

ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+no+9tNGnJppqUmdUWMjhdDYjvexW6glfHoEOIGfFY viminaria@nixos

runcmd:
  - curl -sfL https://get.k3s.io | sh -s - agent
