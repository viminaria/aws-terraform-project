# =============================================================================
# Kubernetes resources — Go API deployment, ClusterIP service, NodePort
# Prerequisite: k3s cluster running with kubeconfig at default path (~/.kube/k3s-cluster)
# Run: cd app/k8s && terraform apply -var="dynamodb_tables={go-api=\"k3s-cluster-go-api-items\"}"
# =============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/k3s-cluster")
  insecure    = true # k3s uses self-signed certs for internal IPs
}

locals {
  dynamodb_tables_var = var.dynamodb_tables
  image_tag_var       = var.image_tag
}

module "kubernetes" {
  source = "../modules/kubernetes"

  kubeconfig_path = pathexpand("~/.kube/k3s-cluster")
  dynamodb_tables = local.dynamodb_tables_var
  image_tag       = local.image_tag_var
}
