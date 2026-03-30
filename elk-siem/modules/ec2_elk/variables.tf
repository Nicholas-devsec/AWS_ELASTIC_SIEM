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

variable "availability_zones" {
  type        = list(string)
  description = "Two AZs for the deployment, in [a, b] order."

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "availability_zones must contain exactly 2 AZs."
  }
}

variable "ami_id" {
  type        = string
  description = "AMI ID for instances."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs (unused in v1, reserved)."
}

variable "private_ingestion_subnet_ids" {
  type        = list(string)
  description = "Private ingestion subnet IDs [az-a, az-b]."
}

variable "private_elk_subnet_ids" {
  type        = list(string)
  description = "Private ELK subnet IDs [az-a, az-b]."
}

variable "private_ingestion_subnet_cidrs" {
  type        = list(string)
  description = "Private ingestion subnet CIDRs [az-a, az-b]."

  validation {
    condition     = length(var.private_ingestion_subnet_cidrs) == 2
    error_message = "private_ingestion_subnet_cidrs must contain exactly 2 CIDRs."
  }
}

variable "private_elk_subnet_cidrs" {
  type        = list(string)
  description = "Private ELK subnet CIDRs [az-a, az-b]."

  validation {
    condition     = length(var.private_elk_subnet_cidrs) == 2
    error_message = "private_elk_subnet_cidrs must contain exactly 2 CIDRs."
  }
}

variable "sg_elasticsearch_id" {
  type        = string
  description = "Security group ID for Elasticsearch."
}

variable "sg_logstash_id" {
  type        = string
  description = "Security group ID for Logstash."
}

variable "sg_kibana_id" {
  type        = string
  description = "Security group ID for Kibana."
}

variable "es_instance_profile_name" {
  type        = string
  description = "Instance profile name for Elasticsearch nodes."
}

variable "logstash_instance_profile_name" {
  type        = string
  description = "Instance profile name for Logstash nodes."
}

variable "kibana_instance_profile_name" {
  type        = string
  description = "Instance profile name for Kibana nodes."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for EBS encryption."
}

variable "es_master_instance_type" {
  type        = string
  description = "ES master instance type."
}

variable "es_data_instance_type" {
  type        = string
  description = "ES data instance type."
}

variable "logstash_instance_type" {
  type        = string
  description = "Logstash instance type."
}

variable "kibana_instance_type" {
  type        = string
  description = "Kibana instance type."
}

variable "es_root_volume_gb" {
  type        = number
  description = "Root volume size (GB) for ES nodes."
}

variable "es_data_volume_gb" {
  type        = number
  description = "Data volume size (GB) for ES data nodes."
}

variable "logstash_root_volume_gb" {
  type        = number
  description = "Root volume size (GB) for Logstash."
}

variable "kibana_root_volume_gb" {
  type        = number
  description = "Root volume size (GB) for Kibana."
}

variable "secret_names" {
  type        = map(string)
  description = "Map of secret names required by user_data."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
