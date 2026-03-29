variable "aws_region" {
  type        = string
  description = "AWS region."
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

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "project" {
  type        = string
  description = "Project tag value."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used for SSE-KMS (S3) and EBS encryption."
}

variable "snapshot_bucket_name" {
  type        = string
  description = "Snapshot bucket name (deterministic name)."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
