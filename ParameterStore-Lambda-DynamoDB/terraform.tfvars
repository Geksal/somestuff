# aws_account_id is now retrieved automatically
aws_region     = "us-east-1"
environment    = "production"
vpc_cidr       = "10.0.0.0/16"
security_email = "security@example.com"  # Replace with your actual security email

# NOTE: Do not store sensitive values like passwords in this file.
# Instead, use environment variables, AWS Secrets Manager, or pass them at runtime.
# For example, to set the database password as an environment variable:
# export TF_VAR_database_master_password="your-secure-password"

# Or use -var="database_master_password=yourpassword" when running terraform apply