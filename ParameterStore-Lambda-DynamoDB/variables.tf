# AWS Account ID is now retrieved dynamically using data source

variable "database_master_password" {
  description = "Master password for database"
  type        = string
  sensitive   = true
}

variable "security_email" {
  description = "Email address for security alerts"
  type        = string
  default     = "security@example.com"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment (e.g. production, staging, development)"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "python3.9"
}

variable "lambda_handler" {
  description = "Handler for the Lambda function"
  type        = string
  default     = "index.handler"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda zip file"
  type        = string
  default     = "lambda.zip"
}