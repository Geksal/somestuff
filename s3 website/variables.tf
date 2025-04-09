# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources"
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket to host the website"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  default     = "dev"
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}