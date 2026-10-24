#!/run/current-system/sw/bin/bash
set -e
# Terraform provides kubeconfig path via env var, fallback to default location
export KUBECONFIG="${KUBECONFIG_PATH:-/home/viminaria/.kube/k3s-cluster}"
curl -sSL "https://github.com/cert-manager/cert-manager/releases/download/v1.21.2/cert-manager.yaml" > /tmp/cert-manager-manifest.yaml
kubectl apply --insecure-skip-tls-verify --validate=false -f /tmp/cert-manager-manifest.yaml
