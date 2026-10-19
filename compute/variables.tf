variable "project_name" {
  description = "Project name"
  type        = string
}

variable "instance_type_cp" {
  description = "Control plane instance type"
  type        = string
}

variable "instance_type_worker" {
  description = "Worker instance type"
  type        = string
}

variable "instance_type_nginx" {
  description = "NGINX instance type"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
  default     = ""
}

variable "ssh_key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "k3s-cluster-key"
}

variable "k3s_version" {
  description = "k3s version"
  type        = string
  default     = "v1.31.2+k3s1"
}

variable "subnet_ids" {
  description = "Map of subnet IDs"
  type = object({
    public  = string
    private = string
  })
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name for EC2 nodes"
  type        = string
}
