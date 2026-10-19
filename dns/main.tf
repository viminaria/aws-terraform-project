# DNS helper — outputs for manual Cloudflare A records (computed post-apply)
locals {
  dns_zone_empty = var.dns_zone == ""
}

output "cloudflare_dns_records" {
  description = "A records to add in Cloudflare (point at NGINX public IP)"
  value = local.dns_zone_empty ? {} : {
    note          = "Create A record: ${var.cp_subdomain}.${var.dns_zone} → <nginx_public_ip after apply>"
    cp_record     = "${var.cp_subdomain}.${var.dns_zone} => <nginx_public_ip after apply>"
    worker_record = "${var.worker_subdomain}.${var.dns_zone} => <nginx_public_ip after apply}"
  }
  sensitive = false
}
