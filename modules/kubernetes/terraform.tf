terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file from k3s cluster"
  type        = string
  default     = "~/.kube/k3s-cluster"
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

variable "image_tag" {
  description = "Container image tag for the Go API (e.g., arm64-latest or a versioned digest)"
  type        = string
  default     = "arm64-latest"
}
