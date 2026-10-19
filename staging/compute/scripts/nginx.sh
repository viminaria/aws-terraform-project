#!/bin/bash
set -euo pipefail

# Install NGINX
apt-get update && apt-get install -y nginx

cat > /etc/nginx/sites-available/kubernetes <<NGINXEOF
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
    upstream k8s_nodes {
        server ${k3s_worker_ip}:32765;
        server ${k3s_control_plane_ip}:32765;
    }

    upstream go_api {
        server ${k3s_worker_ip}:31080;
        server ${k3s_control_plane_ip}:31080;
    }

    server {
        listen 80;
        server_name _;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl;
        server_name _;

        ssl_certificate     /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;

        location /api/ {
            proxy_pass http://go_api;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location / {
            proxy_pass https://${k3s_control_plane_ip};
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
NGINXEOF

# Generate self-signed certificate
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/server.key \
  -out /etc/nginx/ssl/server.crt \
  -subj "/CN=k8s-cluster-nginx/O=Learning"

# Enable site and start NGINX
ln -sf /etc/nginx/sites-available/kubernetes /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
systemctl enable nginx
