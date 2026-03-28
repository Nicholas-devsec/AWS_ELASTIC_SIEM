variable "environment" {
  type        = string
  description = "Environment name."
}

variable "project" {
  type        = string
  description = "Project tag value."
}

variable "internal" {
  type        = bool
  description = "Whether the NLB is internal."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs to place the NLB in."
}

variable "sg_nlb_id" {
  type        = string
  description = "Security group for the NLB (requires NLB SG support)."
}

variable "logstash_instance_ids" {
  type        = list(string)
  description = "Instance IDs for Logstash targets."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

