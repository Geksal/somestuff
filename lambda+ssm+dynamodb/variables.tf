variable "database_master_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

variable "aws_account_id" {
  description = "Your AWS Account ID"
  type        = string
  # You should set this when running terraform
  # e.g., terraform apply -var="aws_account_id=123456789012" -var="database_master_password=secure_password"
}