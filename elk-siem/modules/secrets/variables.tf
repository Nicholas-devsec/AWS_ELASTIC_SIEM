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

