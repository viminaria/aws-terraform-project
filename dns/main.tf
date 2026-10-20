# DNS — creates Cloudflare A records for cp and worker subdomains

locals {
  dns_zone_empty = var.dns_zone == ""
}

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

data "cloudflare_zones" "this" {
  count = local.dns_zone_empty ? 0 : 1
  filter {
    name = var.dns_zone
  }
}

# Control plane A record
resource "cloudflare_record" "cp" {
  count   = local.dns_zone_empty ? 0 : 1
  zone_id = data.cloudflare_zones.this[0].zones[0].id
  name    = var.cp_subdomain
  type    = "A"
  value   = var.nginx_public_ip
  proxied = false
  ttl     = 300
}

# Worker A record (same IP — NGINX forwards to worker)
resource "cloudflare_record" "worker" {
  count   = local.dns_zone_empty ? 0 : 1
  zone_id = data.cloudflare_zones.this[0].zones[0].id
  name    = var.worker_subdomain
  type    = "A"
  value   = var.nginx_public_ip
  proxied = false
  ttl     = 300
}

# NGINX A record (optional dedicated subdomain)
resource "cloudflare_record" "nginx" {
  count   = local.dns_zone_empty || var.nginx_subdomain == "" ? 0 : 1
  zone_id = data.cloudflare_zones.this[0].zones[0].id
  name    = var.nginx_subdomain
  type    = "A"
  value   = var.nginx_public_ip
  proxied = false
  ttl     = 300
}

output "dns_records" {
  description = "Created DNS records"
  value = local.dns_zone_empty ? {} : merge({
    cp       = "${var.cp_subdomain}.${var.dns_zone}"
    worker   = "${var.worker_subdomain}.${var.dns_zone}"
    nginx_ip = var.nginx_public_ip
  }, var.nginx_subdomain != "" ? { nginx = "${var.nginx_subdomain}.${var.dns_zone}" } : {})
}
