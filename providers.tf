terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Placeholder SSM parameter for k8s server URL.
# Real value written by null_resource.extract_k8s_certs after cluster is running.
resource "aws_ssm_parameter" "k8s_server_url" {
  name  = "/k3s/server/url"
  type  = "String"
  value = "https://TEMP:6443"

  tags = {
    Name = "${var.project_name}-k8s-server-url"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "k3s-cluster"
      Environment = "learning"
      ManagedBy   = "terraform"
    }
  }
}
