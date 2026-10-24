#!/usr/bin/env bash
# Extract k3s node token from control plane and store in SSM (if not already set)

NGINX_IP="$1"
CP_PRIVATE_IP="$2"

if [ -z "$NGINX_IP" ] || [ -z "$CP_PRIVATE_IP" ]; then
  echo "Usage: $0 <nginx-ip> <cp-private-ip>"
  exit 1
fi

echo "Waiting for NGINX..."
for i in $(seq 1 90); do
  if ssh -A -i ~/.ssh/k3s-cluster -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@"$NGINX_IP" "echo ok" > /dev/null 2>&1; then
    break
  fi
  sleep 5
done

LOCAL_KEY=$(cat ~/.ssh/k3s-cluster)

TOKEN=""
for i in $(seq 1 90); do
  ssh -A -i ~/.ssh/k3s-cluster -o StrictHostKeyChecking=no ubuntu@"$NGINX_IP" \
    "rm -f /home/ubuntu/.ssh/known_hosts && echo '${LOCAL_KEY}' > /tmp/tmp_key.pem && chmod 600 /tmp/tmp_key.pem" > /dev/null 2>&1

  TOKEN=$(ssh -A -i ~/.ssh/k3s-cluster -o StrictHostKeyChecking=no ubuntu@"$NGINX_IP" \
    "rm -f ~/.ssh/known_hosts && ssh -i /tmp/tmp_key.pem -o StrictHostKeyChecking=no ubuntu@${CP_PRIVATE_IP} 'sudo cat /var/lib/rancher/k3s/server/node-token'" 2>/dev/null)

  TOKEN_LEN=${#TOKEN}
  if [ -n "$TOKEN" ] && [ "$TOKEN_LEN" -gt 10 ]; then
    break
  fi
  sleep 5
done

if [ -z "$TOKEN" ] || [ "${#TOKEN}" -le 10 ]; then
  echo "ERROR: Failed to extract k3s token"
  exit 1
fi

CURRENT=$(aws ssm get-parameter --name /k3s/cluster/token --with-decryption --query Parameter.Value --output text 2>/dev/null)
CURRENT_LEN=${#CURRENT}
if [ "$CURRENT" != "$TOKEN" ]; then
  if [ "$CURRENT_LEN" -gt 10 ] && [ "$CURRENT" != "TEMP" ]; then
    echo "Token updated: ${CURRENT:0:40}... -> ${TOKEN:0:40}..."
  else
    echo "Replacing stale token with fresh one"
  fi
  aws ssm put-parameter --name /k3s/cluster/token --type String --value "$TOKEN" --overwrite
else
  echo "Token already current"
fi
