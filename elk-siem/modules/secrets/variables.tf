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

variable "recovery_window_in_days" {
  type        = number
  description = "Secrets Manager recovery window in days (0 = delete without recovery; recommended 0 for dev)."
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "logstash_role_arn" {
  type        = string
  description = "Logstash role ARN allowed to read logstash and tls secrets."
}

variable "elasticsearch_role_arn" {
  type        = string
  description = "Elasticsearch role ARN allowed to read elasticsearch and tls secrets."
}

variable "kibana_role_arn" {
  type        = string
  description = "Kibana role ARN allowed to read kibana and tls secrets."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
