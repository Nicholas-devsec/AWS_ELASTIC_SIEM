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

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the demo instance."
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the demo instance."
}

variable "instance_type" {
  type        = string
  description = "Instance type for the demo instance."
  default     = "t2.micro"
}

variable "logstash_host" {
  type        = string
  description = "Logstash endpoint (NLB DNS name) for Beats output."
}

variable "logstash_port" {
  type        = number
  description = "Logstash Beats input port."
  default     = 5044
}

variable "admin_cidrs" {
  type        = list(string)
  description = "Optional CIDRs allowed to SSH to the demo instance."
  default     = []
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used for EBS encryption."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

