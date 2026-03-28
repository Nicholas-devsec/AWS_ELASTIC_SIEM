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

