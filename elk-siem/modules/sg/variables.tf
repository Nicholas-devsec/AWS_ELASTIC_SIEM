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

variable "beats_source_cidrs" {
  type        = list(string)
  description = "Allowed CIDRs for Beats ingest."
}

variable "vpn_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed to access Kibana privately."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

