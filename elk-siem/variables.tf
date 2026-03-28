variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-west-2"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., staging, prod)."
}

variable "project" {
  type        = string
  description = "Project tag value."
  default     = "elk-siem"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs for multi-AZ deployment."
  default     = ["us-west-2a", "us-west-2b"]
}

variable "ami_id" {
  type        = string
  description = "AMI ID for all instances (Amazon Linux 2023 or hardened AMI)."
}

variable "allowed_analyst_ips" {
  type        = list(string)
  description = "Reserved for future public Kibana ALB/WAF allowlist; unused when enable_public_kibana=false."
  default     = []
}

variable "beats_source_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to send Beats traffic to Logstash (port 5044)."
}

variable "vpn_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed to access Kibana privately (port 5601)."
}

variable "alert_email" {
  type        = string
  description = "Email address to subscribe to SNS alarm notifications."
}

variable "kms_admin_principal_arn" {
  type        = string
  description = "ARN of the principal allowed to administer the KMS key (e.g., a dedicated admin role)."
}

variable "es_master_instance_type" {
  type        = string
  description = "Elasticsearch master node instance type."
  default     = "r5.large"
}

variable "es_data_instance_type" {
  type        = string
  description = "Elasticsearch data node instance type."
  default     = "r5.xlarge"
}

variable "logstash_instance_type" {
  type        = string
  description = "Logstash instance type."
  default     = "c5.large"
}

variable "kibana_instance_type" {
  type        = string
  description = "Kibana instance type."
  default     = "t3.large"
}

variable "enable_public_kibana" {
  type        = bool
  description = "When true, provisions internet-facing Kibana ALB + WAF (requires ACM). Default false for private-only Kibana."
  default     = false
}

variable "nlb_internal" {
  type        = bool
  description = "Whether the Beats NLB is internal. Default true."
  default     = true
}

variable "retention_hot_days" {
  type        = number
  description = "Hot phase duration for ILM (days)."
  default     = 7
}

variable "retention_warm_days" {
  type        = number
  description = "Warm phase duration for ILM (days)."
  default     = 30
}

variable "retention_delete_days" {
  type        = number
  description = "Delete phase min_age for ILM (days)."
  default     = 90
}

variable "snapshot_glacier_days" {
  type        = number
  description = "Days before transitioning snapshots to Glacier."
  default     = 30
}

variable "snapshot_delete_days" {
  type        = number
  description = "Days before deleting snapshots."
  default     = 365
}

variable "es_root_volume_gb" {
  type        = number
  description = "Root volume size (GB) for ES instances."
  default     = 50
}

variable "es_data_volume_gb" {
  type        = number
  description = "Data volume size (GB) for ES data nodes."
  default     = 200
}

variable "logstash_root_volume_gb" {
  type        = number
  description = "Root volume size (GB) for Logstash instances."
  default     = 30
}

variable "kibana_root_volume_gb" {
  type        = number
  description = "Root volume size (GB) for Kibana instances."
  default     = 30
}
