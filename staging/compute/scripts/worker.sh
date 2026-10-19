#!/bin/bash
set -euo pipefail

# Add swap space (k3s worker is tight on memory)
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Install k3s agent (join via script after terraform apply)
curl -sfL https://get.k3s.io | sh -s - agent
