variable "aws_region" {
  type        = string
  description = "AWS region to deploy backend into."
  default     = "us-west-2"
}

variable "environment" {
  type        = string
  description = "Environment name (staging, prod, etc.)."
}

variable "project" {
  type        = string
  description = "Project name."
  default     = "elk-siem"
}

variable "state_bucket_name" {
  type        = string
  description = "S3 bucket name for Terraform remote state."
}

variable "lock_table_name" {
  type        = string
  description = "DynamoDB table name for Terraform state locking."
  default     = "terraform-locks"
}
