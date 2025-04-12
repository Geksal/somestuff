region = "us-east-1"
environment = "prod"

tags = {
  Project     = "VPC-Flow-Logs"
  Owner       = "Infrastructure"
  ManagedBy   = "Terraform"
}

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.3.0/24",
  "10.0.4.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

flow_logs_retention_days = 30

s3_bucket_name = "my-vpc-flow-logs-bucket-prod-2025"

opensearch_domain_name = "vpc-flow-logs-prod"
opensearch_instance_type = "t3.medium.search"
opensearch_instance_count = 2
opensearch_volume_size = 100

allowed_cidr_blocks = [
  "10.0.0.0/16",  # VPC CIDR
  "192.168.1.0/24" # Corporate network CIDR
]