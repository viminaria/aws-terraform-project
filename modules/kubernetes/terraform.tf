terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

variable "kubeconfig_content" {
  description = "Full kubeconfig YAML content from k3s control plane /etc/rancher/k3s/k3s.yaml"
  type        = string
}

variable "dns_zone" {
  description = "DNS zone for ingress hostnames"
  type        = string
  default     = ""
}

variable "ingress_subdomains" {
  description = "Map of subdomain to app name for Ingress resources (e.g., {go-api = \"go-api\"})"
  type        = map(string)
  default     = {}
}

variable "dynamodb_tables" {
  description = "Map of app name to DynamoDB table name for environment variables"
  type        = map(string)
  default     = {}
}

locals {
  kubeconfig_path = "${pathexpand("~")}/.kube/k3s-cluster"
}

resource "local_file" "kubeconfig" {
  content              = var.kubeconfig_content
  filename             = local.kubeconfig_path
  file_permission      = "0600"
  directory_permission = "0700"
}

provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}
