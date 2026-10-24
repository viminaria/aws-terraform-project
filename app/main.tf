# =============================================================================
# DNS + cert-manager + Kubernetes applications — Cloudflare DNS, ACME certs, and K8s resources
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
  ingress_records  = var.ingress_subdomains
}

# cert-manager — ACME certificate management with Cloudflare DNS-01 challenge
module "cert_manager" {
  source = "../cert-manager"

  kubeconfig_path      = var.kubeconfig_path
  dns_zone             = var.dns_zone
  cloudflare_api_token = var.cloudflare_api_token
  ingress_subdomains   = var.ingress_subdomains
}

# Kubernetes applications — Go API deployment, service, and Traefik IngressRoute
# Only applied when ingress_subdomains is non-empty (i.e., apps are configured)
locals {
  k8s_enabled = length(var.ingress_subdomains) > 0
}

module "kubernetes" {
  source     = "../modules/kubernetes"
  count      = local.k8s_enabled ? 1 : 0
  depends_on = [module.cert_manager]

  kubeconfig_content = var.kubeconfig_content
  dns_zone           = var.dns_zone
  ingress_subdomains = var.ingress_subdomains
  dynamodb_tables    = var.dynamodb_tables
  image_tag          = var.image_tag
}
