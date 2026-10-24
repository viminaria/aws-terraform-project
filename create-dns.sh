#!/bin/bash
# create-dns.sh - Creates Cloudflare A records for a k3s ingress host pointing to the NGINX load balancer
# Usage: ./create-dns.sh <hostname>
# Example: ./create-dns.sh my-service.viminaria.com

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <hostname>"
  echo "Example: $0 my-service.viminaria.com"
  exit 1
fi

HOST="$1"
NGINX_IP="16.192.99.222"
DNS_ZONE="viminaria.com"
API_TOKEN="OPStlyFd6BLY9vBCiI_dnSWKERcB8lEJFI4mL7Cz"

# Get zone ID
ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=$DNS_ZONE" \
  -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['result'][0]['id'])")

# Check if record exists
EXISTING=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$HOST" \
  -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data['result']))")

if [ "$EXISTING" != "0" ]; then
  REC_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$HOST" \
    -H "Authorization: Bearer $API_TOKEN" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['result'][0]['id'])")
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$REC_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$HOST\",\"content\":\"$NGINX_IP\",\"ttl\":300,\"proxied\":false}" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Updated', d['result'][0]['name'] if d.get('success') else 'Failed')"
else
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$HOST\",\"content\":\"$NGINX_IP\",\"ttl\":300,\"proxied\":false}" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Created', d['result']['name'] if d.get('success') else 'Failed')"
fi
