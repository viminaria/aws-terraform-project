# =============================================================================
# DNS + cert-manager — Cloudflare DNS records and ACME certificates
# Prerequisites:
#   1. AWS infra applied (run root first)
#   2. k3s cluster running with kubeconfig at ~/.kube/k3s-cluster
#   3. cloudflare_api_token set via -var or env var TF_VAR_cloudflare_api_token
# =============================================================================

module "dns" {
  source = "../dns"

  dns_zone         = var.dns_zone
  cp_subdomain     = var.cp_subdomain
  worker_subdomain = var.worker_subdomain
  nginx_subdomain  = var.nginx_subdomain
  nginx_public_ip  = var.nginx_public_ip
  ingress_records  = {}
}

# cert-manager — ACME certificate management with Cloudflare DNS-01 challenge
module "cert_manager" {
  source = "../cert-manager"

  kubeconfig_path      = var.kubeconfig_path
  dns_zone             = var.dns_zone
  cloudflare_api_token = var.cloudflare_api_token
  ingress_subdomains   = var.ingress_subdomains
}
