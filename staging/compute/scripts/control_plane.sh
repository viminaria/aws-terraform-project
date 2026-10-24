#!/usr/bin/env bash
set -euo pipefail

# Add swap space (k3s control plane is tight on memory)
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Configure containerd insecure registry for Floci ECR
mkdir -p /etc/rancher/k3s/
cat > /etc/rancher/k3s/registries.yaml <<REGEOF
configs:
  "localhost:4566":
    tls: false
    insecure: true
REGEOF

# Install k3s control plane (Floci EC2 instances have host network access to localhost:4566 ECR)
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --cluster-init
