variable "environment" {
  type        = string
  description = "Environment name."
}

variable "aws_region" {
  type        = string
  description = "AWS region (used for restrictive KMS service conditions)."
}

variable "account_id" {
  type        = string
  description = "AWS account id (12 digits). If empty, derived via aws_caller_identity."
  default     = ""

  validation {
    condition     = var.account_id == "" || can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be empty or a 12-digit AWS account id."
  }
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
