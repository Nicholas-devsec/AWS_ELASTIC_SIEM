variable "environment" {
  type        = string
  description = "Environment name."
}

variable "project" {
  type        = string
  description = "Project tag value."
}

variable "snapshot_bucket_name" {
  type        = string
  description = "Snapshot bucket name."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN to use for SSE-KMS."
}

variable "elasticsearch_role_arn" {
  type        = string
  description = "Elasticsearch role ARN allowed to access snapshot bucket."
}

variable "snapshot_glacier_days" {
  type        = number
  description = "Days before Glacier transition."
}

variable "snapshot_delete_days" {
  type        = number
  description = "Days before delete."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

