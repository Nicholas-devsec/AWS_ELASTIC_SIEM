terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "elk-siem-dev-tfstate-123456789012"
    key            = "elk-siem/dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "elk-siem-dev-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
