#!/usr/bin/env bash
# Extract kubeconfig from k3s control plane via NGINX jump host.
# Usage: ./extract-kubeconfig.sh <nginx_public_ip> [control_plane_private_ip]
set -euo pipefail

NGINX_IP="${1:?Usage: $0 <nginx_ip> [control_plane_ip]}"
CP_IP="${2:-}"
SSH_KEY="${SSH_PRIVATE_KEY:-~/.ssh/k3s-cluster}"
OUTPUT_DIR="${KUBECONFIG_OUTPUT:-$HOME/.kube}"
OUTPUT_FILE="${OUTPUT_DIR}/k3s-cluster"

mkdir -p "$OUTPUT_DIR"

echo "=== Extracting kubeconfig from k3s control plane ==="
echo "NGINX jump host: $NGINX_IP"
if [ -n "$CP_IP" ]; then
  echo "Control plane (override): $CP_IP"
fi

# Get control plane IP from AWS if not provided
if [ -z "$CP_IP" ]; then
  echo "Fetching control plane private IP from AWS..."
  CP_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Role,Values=k3s-server" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].PrivateIpAddress' \
    --output text --region eu-north-1 2>/dev/null)
  if [ -z "$CP_IP" ] || [ "$CP_IP" = "None" ]; then
    echo "ERROR: Could not find running k3s control plane via AWS CLI"
    echo "Tip: Pass it explicitly as $0 <nginx_ip> <control_plane_ip>"
    exit 1
  fi
fi

echo "Control plane IP: $CP_IP"

# Copy SSH key to nginx jump host, then extract kubeconfig from control plane
# Using cat > file redirect instead of ssh -i to avoid path issues on remote side
ssh -o StrictHostKeyChecking=accept-new ubuntu@"$NGINX_IP" \
  -i "$SSH_KEY" "cat > /tmp/kubeconfig_key.pem" < "$SSH_KEY"
chmod 600 /tmp/kubeconfig_key.pem

# Extract kubeconfig from control plane via jump host
KUBECONFIG=$(ssh -o StrictHostKeyChecking=accept-new ubuntu@"$NGINX_IP" \
  -i /tmp/kubeconfig_key.pem \
  "sudo cat /etc/rancher/k3s/k3s.yaml" 2>/dev/null) || {
  echo "ERROR: Failed to read kubeconfig from control plane $CP_IP"
  echo "The k3s server may not be fully initialized yet."
  echo "Wait a few minutes and try again."
  exit 1
}

# Update server URL to use NGINX public IP for external access
KUBECONFIG=$(echo "$KUBECONFIG" | sed "s|https://.*:6443|https://${NGINX_IP}:6443|")

# Write kubeconfig
echo "$KUBECONFIG" > "$OUTPUT_FILE"
chmod 600 "$OUTPUT_FILE"

echo "=== Kubeconfig saved to $OUTPUT_FILE ==="
echo "Verify with: kubectl --kubeconfig=$OUTPUT_FILE get nodes"
