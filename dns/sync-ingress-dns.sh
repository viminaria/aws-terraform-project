#!/bin/bash
# Sync k3s ingress hosts to Cloudflare DNS via SSH through NGINX bastion
set -e

NGINX_IP="16.192.99.222"
SSH_KEY="${HOME}/.ssh/k3s-cluster"
DNS_ZONE="viminaria.com"
API_TOKEN="OPStlyFd6BLY9vBCiI_dnSWKERcB8lEJFI4mL7Cz"

# Query k3s ingress hosts through NGINX bastion → control plane
HOSTS=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$NGINX_IP \
  "ssh -i /tmp/tmp_key.pem -o StrictHostKeyChecking=accept-new ubuntu@10.0.2.191 \
    'kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get ingress --all-namespaces -o json'" 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
hosts = set()
for item in data.get('items', []):
  for r in item.get('spec', {}).get('rules', []):
    h = r.get('host', '')
    if h and not h.startswith('*.'):
      hosts.add(h)
for h in sorted(hosts):
  print(h)
")

if [ -z "$HOSTS" ]; then
  echo "No ingress hosts found in k3s cluster"
  exit 0
fi

ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=$DNS_ZONE" \
  -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'][0]['id'])")

EXISTING=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A" \
  -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; print('\n'.join(r['name'] for r in json.load(sys.stdin)['result'] if r['type']=='A'))")

for host in $HOSTS; do
  if echo "$EXISTING" | grep -qx "$host"; then
    CURRENT_IP=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$host" \
      -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['content'] if d.get('result') else 'MISSING')")
    if [ "$CURRENT_IP" != "16.192.99.222" ]; then
      REC_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$host" \
        -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['id'] if d.get('result') else '')")
      curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$REC_ID" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$host\",\"content\":\"16.192.99.222\",\"ttl\":300,\"proxied\":false}" > /dev/null
      echo "Updated $host"
    else
      echo "OK $host"
    fi
  else
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$host\",\"content\":\"16.192.99.222\",\"ttl\":300,\"proxied\":false}" > /dev/null
    echo "Created $host"
  fi
done

# Clean up orphaned DNS records that point to NGINX IP but no longer have ingress
for record_name in $EXISTING; do
  case "$record_name" in
    aws-control.viminaria.com|aws-worker.viminaria.com|nginx.viminaria.com) continue ;;
  esac
  if ! echo "$HOSTS" | grep -qx "$record_name"; then
    REC_IP=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$record_name" \
      -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['content'] if d.get('result') else '')")
    if [ "$REC_IP" = "16.192.99.222" ]; then
      REC_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$record_name" \
        -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['id'] if d.get('result') else '')")
      if [ -n "$REC_ID" ]; then
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$REC_ID" \
          -H "Authorization: Bearer $API_TOKEN" > /dev/null
        echo "Removed orphaned $record_name"
      fi
    fi
  fi
done
