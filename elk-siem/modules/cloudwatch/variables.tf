variable "aws_region" {
  type        = string
  description = "AWS region."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "project" {
  type        = string
  description = "Project tag value."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for flow logs."
}

variable "vpc_flow_bucket_name" {
  type        = string
  description = "S3 bucket name for VPC flow logs."
}

variable "force_destroy_buckets" {
  type        = bool
  description = "When true, allows Terraform to destroy S3 buckets even if they contain objects/versions."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used for SSE-KMS on the flow logs bucket."
}

variable "alert_email" {
  type        = string
  description = "Email to subscribe to SNS topic."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
