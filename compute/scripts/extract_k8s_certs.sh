#!/usr/bin/env bash
set -e

NGINX_IP="$1"
CP_IP="${2:-}"
SSH_KEY="${HOME}/.ssh/k3s-cluster"
KUBECONFIG_DIR="${HOME}/.kube"

# Copy SSH key to nginx for nested hops using base64 to avoid quoting issues
echo "Copying SSH key to nginx jump host..."
KEY_B64=$(base64 -w0 "$SSH_KEY")
ssh -A -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new ubuntu@"$NGINX_IP" "rm -f /home/ubuntu/.ssh/known_hosts /tmp/tmp_key.pem && echo '$KEY_B64' | base64 -d > /tmp/tmp_key.pem && chmod 600 /tmp/tmp_key.pem && rm -f /home/ubuntu/.ssh/known_hosts"

# Wait for k3s to be ready before extracting certs
echo "Waiting for k3s control plane to be ready..."
for i in $(seq 1 30); do
  if ssh -A -i "$SSH_KEY" ubuntu@"$NGINX_IP" \
    "cat /tmp/tmp_key.pem | ssh -o StrictHostKeyChecking=no -i /tmp/tmp_key.pem -o ConnectTimeout=5 ubuntu@$CP_IP 'sudo test -f /var/lib/rancher/k3s/server/tls/server-ca.crt'" 2>/dev/null; then
    echo "k3s control plane is ready (attempt $i/30)"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: k3s control plane did not become ready after 30 attempts" >&2
    exit 1
  fi
  sleep 5
done

# Extract CA certificate (usually fits in SSM 4KB limit)
echo "Extracting CA certificate..."
CA_CERT=$(ssh -A -i "$SSH_KEY" ubuntu@"$NGINX_IP" \
  "cat /tmp/tmp_key.pem | ssh -o StrictHostKeyChecking=no -i /tmp/tmp_key.pem ubuntu@$CP_IP 'sudo cat /var/lib/rancher/k3s/server/tls/server-ca.crt'")
aws ssm put-parameter --name /k3s/certs/ca --value "$CA_CERT" --type String --overwrite > /dev/null 2>&1 || true

# Extract admin token (small, reliable)
echo "Extracting admin token..."
ADMIN_TOKEN=$(ssh -A -i "$SSH_KEY" ubuntu@"$NGINX_IP" \
  "cat /tmp/tmp_key.pem | ssh -o StrictHostKeyChecking=no -i /tmp/tmp_key.pem ubuntu@$CP_IP 'grep -A1 \"default-token\" /var/lib/rancher/k3s/server/credential-config.yaml 2>/dev/null | tail -1 || cat /var/lib/rancher/k3s/server/token'")
aws ssm put-parameter --name /k3s/admin-token --value "$ADMIN_TOKEN" --type String --overwrite > /dev/null 2>&1 || true

# Update server URL (via nginx public IP for external access)
echo "Extracting server URL..."
SERVER_URL="https://${NGINX_IP}:6443"
aws ssm put-parameter --name /k3s/server/url --value "$SERVER_URL" --type String --overwrite > /dev/null

# Also save kubeconfig to local file (for kubectl and Terraform provider)
echo "Saving kubeconfig..."
mkdir -p "$KUBECONFIG_DIR"
ssh -A -i "$SSH_KEY" ubuntu@"$NGINX_IP" \
  "cat /tmp/tmp_key.pem | ssh -o StrictHostKeyChecking=no -i /tmp/tmp_key.pem ubuntu@$CP_IP 'sudo cat /etc/rancher/k3s/k3s.yaml'" \
  | sed "s/127.0.0.1/${NGINX_IP}/g" > "$KUBECONFIG_DIR/k3s-cluster.tmp"

# Strip CA cert and add insecure-skip-tls-verify since the self-signed cert CN
# is 127.0.0.1, not the NGINX proxy IP — Terraform provider rejects both together
sed -i "/^    certificate-authority-data:/d" "$KUBECONFIG_DIR/k3s-cluster.tmp"
sed -i "/^    server:/a\\    insecure-skip-tls-verify: true" "$KUBECONFIG_DIR/k3s-cluster.tmp"
mv "$KUBECONFIG_DIR/k3s-cluster.tmp" "$KUBECONFIG_DIR/k3s-cluster"
chmod 600 "$KUBECONFIG_DIR/k3s-cluster"
echo "kubeconfig saved to $KUBECONFIG_DIR/k3s-cluster"

echo "All k8s configuration extracted successfully."
