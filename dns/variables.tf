variable "dns_zone" {
  description = "DNS zone"
  type        = string
}

variable "cp_subdomain" {
  description = "Control plane subdomain"
  type        = string
}

variable "worker_subdomain" {
  description = "Worker subdomain"
  type        = string
}

variable "nginx_subdomain" {
  description = "NGINX load balancer subdomain"
  type        = string
  default     = ""
}

variable "ingress_records" {
  description = "Map of ingress subdomain to app name (e.g., {\"go-api.viminaria.com\" = \"go-api\"})"
  type        = map(string)
  default     = {}
}

variable "nginx_public_ip" {
  description = "Public IP of the NGINX load balancer"
  type        = string
}


