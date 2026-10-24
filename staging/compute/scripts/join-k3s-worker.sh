#!/usr/bin/env bash
# join-k3s-worker.sh — Helper script to join k3s worker node after terraform apply
# Usage: ./join-k3s-worker.sh <nginx-public-ip> [<ssh-key-path>] [<cp-private-ip>]

set -euo pipefail

NGINX_IP="${1:?Usage: $0 <nginx-public-ip> [<ssh-key>] [<cp-private-ip>]}"
SSH_KEY="${2:-~/.ssh/k3s-cluster}"

echo "=== Step 1: Getting k3s join token ==="
TOKEN=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$NGINX_IP" \
  "sudo cat /var/lib/rancher/k3s/server/node-token")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not retrieve k3s token from control plane."
  echo "Is the control plane running? Wait a few minutes for k3s to start, then try again."
  exit 1
fi
echo "Token retrieved (first 8 chars): ${TOKEN:0:8}..."

# Try to get CP IP from terraform state (project root is 2 levels up from this script)
TF_DIR="$(cd "$(dirname "$0")/.. && pwd)"
TF_ROOT="${TF_DIR}/.."
CP_IP=$(cd "$TF_ROOT" && terraform output -raw control_plane_private_ip 2>/dev/null || echo "")

if [ -z "$CP_IP" ]; then
  if [ -n "${3:-}" ]; then
    CP_IP="$3"
    echo "WARNING: Terraform state unavailable. Using manually provided IP: $CP_IP"
  else
    echo "ERROR: Could not get control plane IP from terraform state."
    echo "Run from the project directory, or pass CP private IP as third argument:"
    echo "  $0 <nginx-ip> <ssh-key> <cp-private-ip>"
    exit 1
  fi
fi

echo ""
echo "=== Step 2: Joining worker to cluster ==="
echo "Control plane private IP: $CP_IP"
echo "Join token: ${TOKEN:0:8}..."
echo ""
echo "Running join command on worker node..."
echo ""

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$NGINX_IP" "sudo bash <<'INNER_EOF'
  export K3S_TOKEN='${TOKEN}'
  export K3S_URL='https://${CP_IP}:6443'
  curl -sfL https://get.k3s.io | sh -s - agent --token \$K3S_TOKEN --server \$K3S_URL
INNER_EOF"

echo ""
echo "=== Done ==="
echo "Verify: ssh -i ${SSH_KEY} ubuntu@${NGINX_IP} 'sudo k3s kubectl get nodes'"
