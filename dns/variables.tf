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
