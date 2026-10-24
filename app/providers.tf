terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

# Cloudflare provider — required for DNS records + cert-manager DNS-01 challenge
# When api_token is empty, uses a dummy value so init/plan works (all DNS resources are count=0)
locals {
  cf_api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : "A-B-C-D-E-F-G-H-I-J-K-L-M-N-O-P-Q-R-S-T-U-V-W-X-Y-Z-0-9-A-B-C-D-E"
}

provider "cloudflare" {
  api_token = local.cf_api_token
}
