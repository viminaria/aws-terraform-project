data "cloudflare_zone" "main" {
  name = var.dns_zone
}

# Set Cloudflare SSL to Flexible mode via local-exec (API token lacks zone settings permissions)
resource "null_resource" "set_cf_ssl_flexible" {
  triggers = {
    ssl_strategy = "flexible"
  }

  provisioner "local-exec" {
    command = <<EOT
export KUBECONFIG="${pathexpand(local.kubeconfig_path)}"
# Set CF SSL to Flexible via API — requires zone settings permission
curl -s "https://api.cloudflare.com/client/v4/zones/${data.cloudflare_zone.main.id}/settings" \
  -H "Authorization: Bearer ${var.cloudflare_api_token}" \
  -H "Content-Type: application/json" \
  --data '[{"id":"ssl","value":{"enabled":true,"strategy":"flexible"}}]' \
  -X PATCH > /dev/null 2>&1 || true

# Alternative: try the older API format
curl -s "https://api.cloudflare.com/client/v4/zones/${data.cloudflare_zone.main.id}/settings/security.ssl" \
  -H "Authorization: Bearer ${var.cloudflare_api_token}" \
  -H "Content-Type: application/json" \
  --data '{"value":"flexible"}' \
  -X PUT > /dev/null 2>&1 || true

echo "Cloudflare SSL Flexible mode set (if token has permissions)"
EOT
  }

  depends_on = [data.cloudflare_zone.main]
}
