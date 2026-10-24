#!/usr/bin/env bash
set -euo pipefail

# Install NGINX with stream module support
apt-get update && apt-get install -y nginx

# Write complete nginx configuration
cat > /etc/nginx/nginx.conf <<'NGINXEOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

stream {
    upstream k3s_api {
        server ${k3s_control_plane_ip}:6443;
    }

    server {
        listen 6443;
        proxy_pass k3s_api;
        proxy_timeout 1m;
        proxy_connect_timeout 10s;
    }
}

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

# Write the http site configuration for NodePort services
cat > /etc/nginx/sites-available/kubernetes <<'NGINXEOF'
upstream traefik {
    server ${k3s_control_plane_ip}:32765;
    server ${k3s_worker_ip}:32765;
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
