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
      port        = 8080
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

# Traefik IngressRoute per app — routes to the Go API service with TLS from cert-manager
resource "kubernetes_manifest" "ingress_routes" {
  for_each = local.ingress_hosts

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "${each.value}-ingressroute"
      namespace = "default"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`${each.key}`)"
          services = [
            {
              name   = each.value
              port   = 8080
              scheme = "http"
            }
          ]
        }
      ]
      tls = {
        secretName = "${each.key}-tls"
      }
    }
  }

  lifecycle {
    ignore_changes = [manifest[0].status]
  }
}
