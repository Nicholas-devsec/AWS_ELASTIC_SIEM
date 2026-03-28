variable "environment" {
  type        = string
  description = "Environment name."
}

variable "aws_region" {
  type        = string
  description = "AWS region (used for restrictive KMS service conditions)."
}

variable "project" {
  type        = string
  description = "Project name for tags."
}

variable "kms_admin_principal_arn" {
  type        = string
  description = "Principal ARN that administers this key."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

variable "log_delivery_s3_bucket_arns" {
  type        = list(string)
  description = "S3 bucket ARNs that should allow AWS log delivery service to use this CMK for SSE-KMS."
  default     = []
}
