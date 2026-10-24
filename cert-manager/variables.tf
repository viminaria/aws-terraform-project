variable "kubeconfig_path" {
  description = "Path to k8s kubeconfig file (absolute)"
  type        = string
}

variable "dns_zone" {
  description = "DNS zone (e.g. viminaria.com) — must be set for certificates"
  type        = string
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS-01 challenge"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ingress_subdomains" {
  description = "Map of subdomain to app name (e.g. {go-api = \"go-api\"})"
  type        = map(string)
  default     = {}
}
