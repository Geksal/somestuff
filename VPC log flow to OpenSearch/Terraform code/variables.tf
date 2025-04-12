variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC flow logs"
  type        = number
  default     = 14
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for Firehose backup"
  type        = string
}

variable "opensearch_domain_name" {
  description = "Name of the OpenSearch domain"
  type        = string
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch nodes"
  type        = string
}

variable "opensearch_instance_count" {
  description = "Number of instances in the OpenSearch domain"
  type        = number
}

variable "opensearch_volume_size" {
  description = "Size of EBS volumes attached to OpenSearch nodes (in GB)"
  type        = number
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access OpenSearch"
  type        = list(string)
  default     = []
}