#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/update-github-secrets.sh <nginx-public-ip> <control-plane-private-ip> [ssh-key-path]
#
# Extracts kubeconfig from the k3s cluster and uploads necessary secrets to the GitHub repo
# so the deploy.yml CI workflow can run.

NGINX_IP="${1:-}"
CP_PRIVATE_IP="${2:-}"
SSH_KEY="${3:-~/.ssh/k3s-cluster}"

if [ -z "$NGINX_IP" ] || [ -z "$CP_PRIVATE_IP" ]; then
  echo "Usage: $0 <nginx-public-ip> <control-plane-private-ip> [ssh-key-path]"
  echo ""
  echo "After running, commit the updated .github/workflows/deploy.yml secrets references."
  exit 1
fi

KEY_FILE="$(eval echo "$SSH_KEY")"
if [ ! -f "$KEY_FILE" ]; then
  echo "ERROR: SSH key not found at $KEY_FILE"
  exit 1
fi

echo "=== Extracting kubeconfig ==="
KUBECONFIG_CONTENT=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no \
  ubuntu@"$NGINX_IP" \
  "ssh -i /tmp/k3s-cluster-key.pem ubuntu@$CP_PRIVATE_IP 'sudo cat /etc/rancher/k3s/k3s.yaml'" \
  2>/dev/null)

if [ -z "$KUBECONFIG_CONTENT" ]; then
  echo "ERROR: Failed to extract kubeconfig. Verify SSH access and IPs."
  exit 1
fi

# Fix server address — use the control plane private IP directly
KUBECONFIG_CONTENT=$(echo "$KUBECONFIG_CONTENT" | sed "s|server:.*|server: https://$CP_PRIVATE_IP:6443|")

echo "=== Setting GitHub secrets ==="

# Set KUBECONFIG_CONTENT (may be large, stored as-is)
gh secret set KUBECONFIG_CONTENT \
  --body "$KUBECONFIG_CONTENT" \
  --repo "$(git config --get remote.origin.url | sed 's/.*://;s/\.git$//')" 2>/dev/null || \
echo "  ⚠️  Set manually: gh secret set KUBECONFIG_CONTENT --env-file <(cat)"

# Set IP-based secrets (small, always fresh)
gh secret set NGINX_PUBLIC_IP \
  --body "$NGINX_IP" \
  --repo "$(git config --get remote.origin.url | sed 's/.*://;s/\.git$//')"

gh secret set CONTROL_PLANE_PRIVATE_IP \
  --body "$CP_PRIVATE_IP" \
  --repo "$(git config --get remote.origin.url | sed 's/.*://;s/\.git$//')"

# Derive DNS zone from kubeconfig server hostname (best-effort)
DNS_ZONE=$(echo "$KUBECONFIG_CONTENT" | grep -oP '(?<=server: https://)[^:]+' | head -1 | sed 's/^[^.]*\.\([^.]*\.[^.]*\)$/\1/' 2>/dev/null || echo "")

if [ -n "$DNS_ZONE" ]; then
  gh secret set DNS_ZONE \
    --body "$DNS_ZONE" \
    --repo "$(git config --get remote.origin.url | sed 's/.*://;s/\.git$//')"
fi

gh secret set INGRESS_SUBDOMAINS_JSON \
  --body '{"go-api": "go-api"}' \
  --repo "$(git config --get remote.origin.url | sed 's/.*://;s/\.git$//')"

gh secret set DYNAMODB_TABLES_JSON \
  --body '{"go-api": "k3s-cluster-go-api-items"}' \
  --repo "$(git config --get remote.origin.url | sed 's/.*://;s/\.git$//')"

echo ""
echo "=== Done ==="
echo "Secrets set on repo: $(git config --get remote.origin.url | sed 's/.*://;s/\.git$//')"
echo ""
echo "Next steps:"
echo "  1. Verify secrets: gh secret list --repo $(git config --get remote.origin.url | sed 's/.*://;s/\.git$//')"
echo "  2. Trigger deploy: gh workflow run deploy.yml --field image_tag=arm64-latest"
