variable "environment" {
  type        = string
  description = "Environment name."
}

variable "project" {
  type        = string
  description = "Project tag value."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR."
}

variable "availability_zones" {
  type        = list(string)
  description = "Two AZs for the deployment."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

