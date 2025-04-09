# terraform.tfvars
# Customize these values for your environment

aws_region          = "us-east-1"
bucket_name         = "my-cors-website-example"
environment         = "dev"
cors_allowed_origins = [
  "https://example.com",
  "http://localhost:3000"
]