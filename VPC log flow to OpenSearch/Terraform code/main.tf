# Provider Block
provider "aws" {
  profile = "default"
  region  = var.region
}

# Get current region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Apply common tags to all resources
locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
    }
  )
}

##############################
# VPC Creation 
##############################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-vpc"
    }
  )
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-public-subnet-${count.index + 1}"
      Tier = "Public"
    }
  )
}

# Create private subnets
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = false
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-subnet-${count.index + 1}"
      Tier = "Private"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-igw"
    }
  )
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs) > 0 ? 1 : 0
  domain = "vpc"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-nat-eip"
    }
  )
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.public_subnet_cidrs) > 0 ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-nat-gw"
    }
  )
  
  depends_on = [aws_internet_gateway.igw]
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-public-rt"
    }
  )
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  dynamic "route" {
    for_each = length(aws_nat_gateway.nat_gw) > 0 ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat_gw[0].id
    }
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-private-rt"
    }
  )
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

##############################
# S3 Bucket Creation
##############################
resource "aws_s3_bucket" "bucket" {
  bucket = var.s3_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##############################
# OpenSearch Domain
##############################
resource "aws_opensearch_domain" "my_tetescik" {
  domain_name    = var.opensearch_domain_name
  engine_version = "OpenSearch_2.5"

  cluster_config {
    instance_type  = var.opensearch_instance_type
    instance_count = var.opensearch_instance_count
    
    zone_awareness_enabled = var.opensearch_instance_count >= 2
    dynamic "zone_awareness_config" {
      for_each = var.opensearch_instance_count >= 2 ? [1] : []
      content {
        availability_zone_count = 2
      }
    }
  }
  
  vpc_options {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.opensearch_sg.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.opensearch_volume_size
    volume_type = "gp3"
  }
  
  encrypt_at_rest {
    enabled = true
  }
  
  node_to_node_encryption {
    enabled = true
  }
  
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }
  
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "es:ESHttpPut",
          "es:ESHttpPost",
          "es:ESHttpGet"
        ]
        Resource = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*"
        Condition = {
          StringEquals = {
            "aws:PrincipalArn": aws_iam_role.firehose_role.arn
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

##############################
# Security Groups
##############################
resource "aws_security_group" "opensearch_sg" {
  name        = "${var.environment}-opensearch-sg"
  description = "Security group for OpenSearch domain"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = concat([var.vpc_cidr], var.allowed_cidr_blocks)
    description     = "HTTPS access to OpenSearch"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = local.common_tags
}

resource "aws_security_group" "firehose_sg" {
  name        = "${var.environment}-firehose-sg"
  description = "Security group for Kinesis Firehose"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS outbound to OpenSearch"
  }

  tags = local.common_tags
}

resource "aws_security_group_rule" "opensearch_ingress_firehose" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.firehose_sg.id
  security_group_id        = aws_security_group.opensearch_sg.id
  description             = "Allow incoming HTTPS from Firehose"
}

##############################
# VPC Flow Logs
##############################
resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  iam_role_arn         = aws_iam_role.flow_logs_role.arn
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "${var.environment}-vpc-flow-logs-group-new"
  retention_in_days = var.flow_logs_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "firehose_errors" {
  name              = "/aws/firehose/${var.environment}-opensearch-delivery-errors-new"
  retention_in_days = 14
  tags              = local.common_tags
}

##############################
# IAM Roles and Policies
##############################
# Flow Logs Role
resource "aws_iam_role" "flow_logs_role" {
  name = "${var.environment}-vpc-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs_policy" {
  name = "${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = [
          aws_cloudwatch_log_group.flow_logs.arn,
          "${aws_cloudwatch_log_group.flow_logs.arn}:*"
        ]
      }
    ]
  })
}

# Firehose Role
resource "aws_iam_role" "firehose_role" {
  name = "${var.environment}-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "${var.environment}-FirehoseDeliveryPolicy"
  role = aws_iam_role.firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:DescribeElasticsearchDomain",
          "es:DescribeElasticsearchDomains",
          "es:DescribeElasticsearchDomainConfig",
          "es:ESHttpPut",
          "es:ESHttpPost",
          "es:ESHttpGet",
          "es:ESHttpDelete"
        ]
        Resource = [
          aws_opensearch_domain.my_tetescik.arn,
          "${aws_opensearch_domain.my_tetescik.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.bucket.arn,
          "${aws_s3_bucket.bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.flow_logs.arn,
          "${aws_cloudwatch_log_group.flow_logs.arn}:*",
          aws_cloudwatch_log_group.firehose_errors.arn,
          "${aws_cloudwatch_log_group.firehose_errors.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_vpc_access" {
  name = "${var.environment}-firehose-vpc-access"
  role = aws_iam_role.firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch to Firehose Role
resource "aws_iam_role" "cloudwatch_to_firehose" {
  name = "${var.environment}-cloudwatch-to-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "cloudwatch_to_firehose_policy" {
  name = "${var.environment}-CloudWatchToFirehosePolicy"
  role = aws_iam_role.cloudwatch_to_firehose.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = [aws_kinesis_firehose_delivery_stream.firehose.arn]
      },
      {
        Effect = "Allow"
        Action = ["logs:PutSubscriptionFilter"]
        Resource = [aws_cloudwatch_log_group.flow_logs.arn]
      }
    ]
  })
}

##############################
# Kinesis Firehose
##############################
resource "aws_kinesis_firehose_delivery_stream" "firehose" {
  name        = "${var.environment}-kinesis-firehose-opensearch-stream"
  destination = "elasticsearch"

  elasticsearch_configuration {
    domain_arn     = aws_opensearch_domain.my_tetescik.arn
    role_arn       = aws_iam_role.firehose_role.arn
    index_name     = "vpc-flow-logs"
    index_rotation_period = "OneDay"
    
    vpc_config {
      subnet_ids         = [aws_subnet.private[0].id]
      security_group_ids = [aws_security_group.firehose_sg.id]
      role_arn          = aws_iam_role.firehose_role.arn
    }
    
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_errors.name
      log_stream_name = "ElasticsearchDeliveryErrors"
    }



    s3_configuration {
      role_arn           = aws_iam_role.firehose_role.arn
      bucket_arn         = aws_s3_bucket.bucket.arn
      prefix             = "opensearch-failures/"
      buffering_size     = 10
      buffering_interval = 300
      compression_format = "GZIP"
    }
  }
  
  depends_on = [aws_iam_role_policy.firehose_policy]
  
  tags = local.common_tags
}



##############################
# CloudWatch Log Subscription
##############################
resource "aws_cloudwatch_log_subscription_filter" "flow_logs_to_firehose" {
  name            = "${var.environment}-flow-logs-to-firehose"
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  log_group_name  = aws_cloudwatch_log_group.flow_logs.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.firehose.arn
  distribution    = "Random"
}