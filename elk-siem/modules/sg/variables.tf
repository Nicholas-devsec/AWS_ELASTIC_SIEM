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

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR (used for optional internal Beats allowlist)."
}

variable "beats_source_cidrs" {
  type        = list(string)
  description = "Allowed CIDRs for Beats ingest."
}

variable "beats_allow_vpc_cidr" {
  type        = bool
  description = "When true, also allows Beats ingest from within the VPC CIDR."
  default     = true
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
