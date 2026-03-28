variable "enable_public_kibana" {
  type        = bool
  description = "When true, create internet-facing ALB + WAF for Kibana."
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
  description = "VPC ID."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs."
}

variable "allowed_analyst_ips" {
  type        = list(string)
  description = "Analyst IP allowlist (CIDRs) for WAF."
  default     = []
}

variable "kibana_instance_id" {
  type        = string
  description = "Kibana instance ID."
}

variable "sg_alb_id" {
  type        = string
  description = "ALB security group ID."
}

variable "acm_cert_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listener (required if enable_public_kibana=true)."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

