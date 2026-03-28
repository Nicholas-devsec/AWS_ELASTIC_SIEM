terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state backend (recommended):
  # - Create via ../bootstrap first, then paste the backend config here.
  # backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

