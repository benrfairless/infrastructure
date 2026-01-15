
terraform {
  # OpenTofu 1.6.0+ is compatible with Terraform 1.6.0+
  # This configuration works with both OpenTofu and Terraform
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Updated to AWS provider 5.x for modern AWS features
      version = "~> 5.82.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      # Updated to Cloudflare provider 4.x latest
      version = "~> 4.48.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.5"
    }
    linode = {
      source  = "linode/linode"
      version = "~> 2.33.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5.0"
    }
  }
}
