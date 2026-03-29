variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-west-2"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., staging, prod)."

  validation {
    condition     = length(trimspace(var.environment)) > 0 && can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must be non-empty and match ^[a-z0-9-]+$ (e.g., dev, staging, prod)."
  }
}

variable "project" {
  type        = string
  description = "Project tag value."
  default     = "elk-siem"
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

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs for multi-AZ deployment."
  default     = ["us-west-2a", "us-west-2b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "availability_zones must contain exactly 2 AZs (e.g., [\"us-west-2a\",\"us-west-2b\"])."
  }
}

variable "ami_id" {
  type        = string
  description = "AMI ID for all instances (Amazon Linux 2023 or hardened AMI)."

  validation {
    condition     = can(regex("^ami-[0-9a-fA-F]{8,}$", var.ami_id))
    error_message = "ami_id must look like an AMI id (e.g., ami-0123456789abcdef0)."
  }
}

variable "allowed_analyst_ips" {
  type        = list(string)
  description = "Reserved for future public Kibana ALB/WAF allowlist; unused when enable_public_kibana=false."
  default     = []

  validation {
    condition = (
      alltrue([for c in var.allowed_analyst_ips : can(cidrnetmask(c))]) &&
      (!var.enable_public_kibana || length(var.allowed_analyst_ips) > 0)
    )
    error_message = "allowed_analyst_ips must be valid CIDRs; when enable_public_kibana=true it must be non-empty."
  }
}

variable "beats_source_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to send Beats traffic to Logstash (port 5044)."

  validation {
    condition     = length(var.beats_source_cidrs) > 0 && alltrue([for c in var.beats_source_cidrs : can(cidrnetmask(c))])
    error_message = "beats_source_cidrs must be a non-empty list of valid CIDRs."
  }
}

variable "vpn_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed to access Kibana privately (port 5601)."

  validation {
    condition     = length(var.vpn_cidr_blocks) > 0 && alltrue([for c in var.vpn_cidr_blocks : can(cidrnetmask(c))])
    error_message = "vpn_cidr_blocks must be a non-empty list of valid CIDRs."
  }
}

variable "alert_email" {
  type        = string
  description = "Email address to subscribe to SNS alarm notifications."

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address (used for SNS subscription)."
  }
}

variable "kms_admin_principal_arn" {
  type        = string
  description = "ARN of the principal allowed to administer the KMS key (e.g., a dedicated admin role)."

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/.+$", var.kms_admin_principal_arn))
    error_message = "kms_admin_principal_arn must be an IAM role/user ARN (e.g., arn:aws:iam::123456789012:role/security-admin)."
  }
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

variable "acm_cert_arn" {
  type        = string
  description = "ACM certificate ARN for the Kibana ALB HTTPS listener (required if enable_public_kibana=true)."
  default     = ""

  validation {
    condition     = !var.enable_public_kibana || can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/.+$", var.acm_cert_arn))
    error_message = "When enable_public_kibana=true, acm_cert_arn must be set to a valid ACM certificate ARN."
  }
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
