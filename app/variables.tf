variable "dns_zone" {
  description = "Your Cloudflare domain (e.g. example.com) — empty to skip DNS + certs"
  type        = string
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token for DNS and cert-manager DNS-01 challenge"
  type        = string
  sensitive   = true
  default     = ""
}

variable "nginx_public_ip" {
  description = "Public IP of the NGINX load balancer (from root compute module)"
  type        = string
  default     = ""
}

variable "kubeconfig_path" {
  description = "Path to k8s kubeconfig file for cert-manager and kubernetes provider"
  type        = string
  default     = "~/.kube/k3s-cluster"
}

variable "cp_subdomain" {
  description = "Subdomain prefix for control plane DNS record"
  type        = string
  default     = "aws-control"
}

variable "worker_subdomain" {
  description = "Subdomain prefix for worker DNS record"
  type        = string
  default     = "aws-worker"
}

variable "nginx_subdomain" {
  description = "Subdomain prefix for NGINX load balancer DNS record"
  type        = string
  default     = ""
}

variable "ingress_subdomains" {
  description = "Map of ingress subdomain prefix to app name (e.g. {go-api = \"go-api\"})"
  type        = map(string)
  default     = { go-api = "go-api" }
}

variable "dynamodb_tables" {
  description = "Map of app name to DynamoDB table name for environment variables"
  type        = map(string)
  default     = {}
}

variable "image_tag" {
  description = "Container image tag for the Go API (e.g. arm64-latest or a versioned digest)"
  type        = string
  default     = "arm64-latest"
}
