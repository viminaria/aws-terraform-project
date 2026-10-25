# =============================================================================
# DNS + Kubernetes applications — Cloudflare DNS, ACME certs, and K8s resources
# Prerequisites:
#   1. AWS infra applied (run root first)
#   2. k3s cluster running with kubeconfig at ~/.kube/k3s-cluster (default path)
#   3. cloudflare_api_token set via -var or env var TF_VAR_cloudflare_api_token
# =============================================================================

locals {
  have_dns = var.dns_zone != ""
}

module "dns" {
  count = local.have_dns ? 1 : 0

  source = "../dns"

  dns_zone         = var.dns_zone
  cp_subdomain     = var.cp_subdomain
  worker_subdomain = var.worker_subdomain
  nginx_subdomain  = var.nginx_subdomain
  nginx_public_ip  = var.nginx_public_ip
  ingress_records  = local.have_dns ? var.ingress_subdomains : {}
}

# cert-manager — ACME certificate management with Cloudflare DNS-01 challenge
# (Disabled for now; add back when needed)

module "kubernetes" {
  source = "../modules/kubernetes"

  kubeconfig_path = pathexpand(var.kubeconfig_path)
  dynamodb_tables = var.dynamodb_tables
  image_tag       = var.image_tag
}
