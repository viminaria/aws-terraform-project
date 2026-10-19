#!/bin/bash
set -euo pipefail

# Add swap space (k3s control plane is tight on memory)
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Install k3s control plane (no public IP needed, NAT GW handles outbound)
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --cluster-init
