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

# NodePort service for direct access when DNS/certs not configured
resource "kubernetes_service_v1" "go_api_nodeport" {
  metadata {
    name = "go-api-nodeport"
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
      node_port   = 30080
    }
    type = "NodePort"
  }
}
