locals {
  ingress_hosts = { for k, v in var.ingress_subdomains : "${k}.${var.dns_zone}" => v if var.dns_zone != "" }
}

resource "kubernetes_deployment_v1" "go_api" {
  metadata {
    name = "go-api"
    labels = {
      app = "go-api"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "go-api"
      }
    }
    template {
      metadata {
        labels = {
          app = "go-api"
        }
      }
      spec {
        container {
          name  = "go-api"
          image = "ghcr.io/viminaria/go-http-api-project:${var.image_tag}"

          port {
            container_port = 8080
          }

          env {
            name  = "DYNAMODB_TABLE"
            value = lookup(var.dynamodb_tables, "go-api", "k3s-cluster-go-api-items")
          }
          env {
            name  = "AWS_REGION"
            value = "eu-north-1"
          }
          env {
            name  = "PORT"
            value = "8080"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "go_api" {
  metadata {
    name = "go-api"
    labels = {
      app = "go-api"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment_v1.go_api.spec[0].template[0].metadata[0].labels["app"]
    }
    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

# One Ingress per app, keyed by ingress hostname — uses cert-manager TLS secrets
resource "kubernetes_manifest" "ingress_hosts" {
  for_each = local.ingress_hosts

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name = "${each.value}-ingress"
      annotations = {
        "traefik.middlewares.kubernetes.io/crd" = "true"
        "cert-manager.io/cluster-issuer"        = "letsencrypt-prod"
      }
    }
    spec = {
      ingressClassName = "traefik"
      tls = [
        {
          hosts      = [each.key]
          secretName = "${each.key}-tls"
        }
      ]
      rule = {
        http = {
          path = {
            path     = "/"
            pathType = "Prefix"
            backend = {
              service = {
                name = each.value
                port = {
                  number = 80
                }
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [manifest[0].spec[0].rule[0].http[0].path[0].backend]
  }
}
