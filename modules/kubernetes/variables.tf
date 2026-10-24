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

variable "image_tag" {
  description = "Container image tag for the Go API (e.g., arm64-latest or a versioned digest)"
  type        = string
  default     = "arm64-latest"
}
