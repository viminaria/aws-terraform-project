terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

locals {
  ingress_domains = toset([for k, v in var.ingress_subdomains : "${k}.${var.dns_zone}" if var.dns_zone != ""])
}

# Kubernetes provider for cert-manager k8s resources
provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}

# =============================================================================
# Install cert-manager CRDs + controller (one-time, idempotent)
# =============================================================================
resource "null_resource" "install_cert_manager" {
  triggers = {
    # Reinstall if manifest URL changes (new version)
    manifest_url = "https://github.com/cert-manager/cert-manager/releases/download/v1.21.2/cert-manager.yaml"
  }

  provisioner "local-exec" {
    command     = "${path.module}/scripts/install-cert-manager.sh"
    environment = { KUBECONFIG_PATH = pathexpand(var.kubeconfig_path) }
  }

  depends_on = [kubernetes_secret_v1.cloudflare_api_token]
}

# =============================================================================
# Cloudflare API token secret (reused by ClusterIssuer)
# =============================================================================
resource "kubernetes_secret_v1" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "cert-manager"
  }

  data = {
    api-token = var.cloudflare_api_token
  }
}

# =============================================================================
# ClusterIssuer — ACME with Cloudflare DNS-01 challenge
# =============================================================================
resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = kubernetes_secret_v1.cloudflare_api_token.metadata[0].name
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }

  lifecycle {
    ignore_changes = [manifest[0].status]
  }

  depends_on = [null_resource.install_cert_manager, kubernetes_secret_v1.cloudflare_api_token]
}

# =============================================================================
# Certificate per ingress subdomain
# =============================================================================
resource "kubernetes_manifest" "certificates" {
  for_each = local.ingress_domains

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = each.key
      namespace = "default"
    }
    spec = {
      secretName = "${each.key}-tls"
      issuerRef = {
        name = kubernetes_manifest.cluster_issuer.manifest[0].metadata[0].name
        kind = "ClusterIssuer"
      }
      dnsNames = [each.key]
    }
  }

  lifecycle {
    ignore_changes = [manifest[0].status]
  }

  depends_on = [kubernetes_manifest.cluster_issuer]
}

# =============================================================================
# Outputs
# =============================================================================
output "cert_secret_names" {
  description = "Map of domain to k8s TLS secret name created by cert-manager"
  value       = { for d in local.ingress_domains : d => "${d}-tls" }
}
