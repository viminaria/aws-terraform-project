variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "k3s-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (nginx load balancer lives here)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (k3s nodes live here)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "k3s_version" {
  description = "k3s version to install"
  type        = string
  default     = "v1.31.2+k3s1"
}

variable "instance_type_cp" {
  description = "EC2 instance type for k3s control plane"
  type        = string
  default     = "t4g.small"
}

variable "instance_type_worker" {
  description = "EC2 instance type for k3s worker"
  type        = string
  default     = "t4g.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB for EC2 instances"
  type        = number
  default     = 20
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for the application"
  type        = string
  default     = "k3s-cluster-app-data"
}

variable "go_api_dynamodb_table_name" {
  description = "Name of the DynamoDB table for the Go API"
  type        = string
  default     = "k3s-cluster-go-api-items"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for the application"
  type        = string
  default     = "k3s-cluster-app-storage"
}

variable "ssh_public_key" {
  description = "SSH public key to authorize access to EC2 instances"
  type        = string
  default     = ""
}

variable "ssh_key_name" {
  description = "Name for the AWS key pair resource"
  type        = string
  default     = "k3s-cluster-key"
}

variable "instance_type_nginx" {
  description = "EC2 instance type for NGINX load balancer"
  type        = string
  default     = "t4g.micro"
}

variable "cp_subdomain" {
  description = "Subdomain prefix for control plane DNS record"
  type        = string
  default     = "aws-control"
}

variable "dns_zone" {
  description = "Your domain name for Cloudflare DNS (e.g. example.com)"
  type        = string
  default     = ""
}

variable "nginx_subdomain" {
  description = "Subdomain prefix for NGINX load balancer DNS record"
  type        = string
  default     = ""
}

variable "worker_subdomain" {
  description = "Subdomain prefix for worker DNS record"
  type        = string
  default     = "aws-worker"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for optional IaC DNS management (leave empty for manual DNS)"
  type        = string
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for optional IaC DNS management"
  type        = string
  default     = ""
}

variable "ingress_subdomains" {
  description = "Map of ingress subdomains to app names (e.g., {\"go-api\" = \"go-api\"}) for automatic DNS + Ingress creation"
  type        = map(string)
  default     = {}
}

variable "external_ip" {
  description = "Your public IPv4 CIDR for SSH access restriction"
  type        = string
  default     = "0.0.0.0/0"
}

variable "kubeconfig_content" {
  description = "Full kubeconfig YAML content from k3s control plane /etc/rancher/k3s/k3s.yaml"
  type        = string
  sensitive   = true
}
