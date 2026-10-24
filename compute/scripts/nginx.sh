#!/usr/bin/env bash
set -euo pipefail

# Install NGINX with stream module support
apt-get update && apt-get install -y jq

# Get private IPs of all instances tagged as k3s nodes (control plane + workers)
NODE_IPS=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=k3s-cluster" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PrivateIpAddress' --output text 2>/dev/null | tr '\t' ',' || true)

# Fallback if AWS CLI not available or no instances found yet at boot time
if [ -z "$NODE_IPS" ]; then
  NODE_IPS="${fallback_cp_ip}"
fi

# Write base nginx config (static parts)
cat > /etc/nginx/nginx.conf <<'NGINXEOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}
NGINXEOF

# Build upstream block with discovered IPs and append to nginx.conf
{
  echo ""
  echo "stream {"
  echo "    upstream k3s_api {"
  IFS=',' read -ra IPS <<< "$NODE_IPS"
  for ip in "$${IPS[@]}"; do
    if [ -n "$ip" ]; then
      echo "        server $${ip}:6443;"
    fi
  done
  echo "    }"
  echo ""
  echo "    server {"
  echo "        listen 6443;"
  echo "        proxy_pass k3s_api;"
  echo "        proxy_timeout 1m;"
  echo "        proxy_connect_timeout 10s;"
  echo "    }"
  echo "}"
} >> /etc/nginx/nginx.conf

# Append http block (static)
cat >> /etc/nginx/nginx.conf <<'NGINXEOF'

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGINXEOF

# Build traefik upstream with all node IPs
{
  echo "upstream traefik {"
  IFS=',' read -ra IPS <<< "$NODE_IPS"
  for ip in "$${IPS[@]}"; do
    if [ -n "$ip" ]; then
      echo "    server $${ip}:32765;"
    fi
  done
} > /etc/nginx/sites-available/kubernetes

# Append remaining static config (triple-quoted heredoc so $ signs aren't expanded)
cat >> /etc/nginx/sites-available/kubernetes <<'NGINXEOF'
}

server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    location / {
        proxy_pass http://traefik;
    }
}
NGINXEOF

# Generate self-signed certificate
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa-2048 \
  -keyout /etc/nginx/ssl/server.key \
  -out /etc/nginx/ssl/server.crt \
  -subj "/CN=k8s-cluster-nginx/O=Learning"

# Enable site and start NGINX
ln -sf /etc/nginx/sites-available/kubernetes /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
systemctl enable nginx

# Verify stream module is loaded and port 6443 is listening
sleep 2
if ! ss -tlnp | grep -q ":6443"; then
    echo "WARNING: Port 6443 not listening, restarting nginx..."
    systemctl restart nginx
fi
