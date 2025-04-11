# Provider Block
provider "aws" {
  profile = "default"
  region  = var.aws_region
}

# Get AWS Account ID automatically
data "aws_caller_identity" "current" {}

##############################
# VPC and Network Security
##############################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "main-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"

  tags = {
    Name        = "private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "lambda-sg"
    Environment = var.environment
  }
}

# VPC Endpoints
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Environment = var.environment
    Name        = "s3-endpoint"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "private-route-table"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Environment = var.environment
    Name        = "dynamodb-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true

  tags = {
    Environment = var.environment
    Name        = "ssm-endpoint"
  }
}

##############################
# SSM Parameter Store for Database Password
##############################
resource "aws_ssm_parameter" "secret" {
  name        = "/${var.environment}/database/password/master"
  description = "The parameter description"
  type        = "SecureString"
  value       = var.database_master_password

  tags = {
    environment = var.environment
  }
}

##############################
# DynamoDB Table Resource with AWS-managed encryption and TTL
##############################
resource "aws_dynamodb_table" "example" {
  name           = "my-dynamodb-table"
  hash_key       = "id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "id"
    type = "S"  # String data type for the primary key
  }

  # Enable TTL for automatic data expiration
  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  # Enable server-side encryption with AWS managed key
  server_side_encryption {
    enabled = true
  }

  # Enable point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    environment = var.environment
  }
}

##############################
# S3 Bucket for Lambda code with AWS-managed encryption
##############################
resource "aws_s3_bucket" "example" {
  bucket = "my-lambda-trigger-bucket-${random_id.bucket_suffix.hex}"
  
  # Enable force_destroy to allow easier deletion
  force_destroy = true

  tags = {
    Environment = var.environment
    Name        = "lambda-code-bucket"
  }
}

# Generate a random string to make bucket name unique
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Block public access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption with AWS managed key (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Add lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    id     = "archive-and-delete"
    status = "Enabled"

    filter {
      prefix = ""  # Apply to all objects
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete objects after 1 year
    expiration {
      days = 365
    }
  }

  # Add a rule for noncurrent versions
  rule {
    id     = "noncurrent-version-expiration"
    status = "Enabled"
    
    filter {
      prefix = ""  
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Configure CORS if needed
resource "aws_s3_bucket_cors_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://yourdomain.com"] # Restrict to only trusted domains
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Bucket policy
resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.example.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowSSLRequestsOnly",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource = [
          aws_s3_bucket.example.arn,
          "${aws_s3_bucket.example.arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      },
      {
        Sid       = "AllowLambdaRoleAccess",
        Effect    = "Allow",
        Principal = {
          AWS = aws_iam_role.lambda_exec.arn
        },
        Action    = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.example.arn,
          "${aws_s3_bucket.example.arn}/*"
        ]
      },
      {
        Sid       = "AllowRootUserFullAccess",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = "s3:*",
        Resource = [
          aws_s3_bucket.example.arn,
          "${aws_s3_bucket.example.arn}/*"
        ]
      }
    ]
  })
}

# Set up access logging
resource "aws_s3_bucket" "log_bucket" {
  bucket = "access-logs-${random_id.bucket_suffix.hex}"
  
  # Enable force_destroy to allow easier deletion
  force_destroy = true

  tags = {
    Environment = var.environment
    Name        = "access-logs-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "archive-and-delete-logs"
    status = "Enabled"
    
    filter {
      prefix = ""  
    }

    # Transition to Glacier after 30 days
    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    # Delete objects after 2 years (compliance requirement)
    expiration {
      days = 730
    }
  }
}

resource "aws_s3_bucket_logging" "example" {
  bucket = aws_s3_bucket.example.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "access-logs/"
}

##############################
# IAM Role for Lambda with updated policies
##############################
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect   = "Allow",
      Sid      = ""
    }]
  })

  # Add tags for the role
  tags = {
    Environment = var.environment
  }
}

# Updated IAM policy to allow Lambda to access SSM Parameter Store and DynamoDB
resource "aws_iam_role_policy" "lambda_ssm_dynamodb_policy" {
  name = "lambda-ssm-dynamodb-access-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "ssm:GetParameter",
        Effect   = "Allow",
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}/database/password/master",
        Condition = {
          StringEquals = {
            "aws:ResourceTag/environment": var.environment
          }
        }
      },
      {
        Action   = [
          "dynamodb:PutItem",
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.example.arn,
        Condition = {
          StringEquals = {
            "aws:ResourceTag/environment": var.environment
          }
        }
      },
      # Specific permission for querying with the hash key
      {
        Action   = [
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = "${aws_dynamodb_table.example.arn}/index/*"
      }
    ]
  })
}

# Add SQS permissions for Lambda (for dead letter queue)
resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "lambda-sqs-access-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ],
        Effect   = "Allow",
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

# Add specific CloudWatch Logs permissions
resource "aws_iam_role_policy" "lambda_logging" {
  name   = "lambda-logging-policy"
  role   = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*",
        Condition = {
          StringEquals = {
            "aws:RequestTag/Environment": var.environment
          }
        }
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.example.function_name}:*"
      }
    ]
  })
}

# Add VPC access for Lambda
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# SQS for Dead Letter Queue
resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "lambda-dead-letter-queue"
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10

  tags = {
    Environment = var.environment
  }
}

##############################
# Lambda function with VPC configuration
##############################
resource "aws_lambda_function" "example" {
  function_name = "dynamodb-lambda"
  role          = aws_iam_role.lambda_exec.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime

  # Reference Lambda code from the S3 bucket
  s3_bucket = aws_s3_bucket.example.bucket
  s3_key    = "lambda.zip"

  # Place Lambda in VPC
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.example.name
      SSM_PARAM_NAME = aws_ssm_parameter.secret.name
    }
  }

  depends_on = [aws_s3_object.lambda_zip]

  # Add dead letter queue configuration (sends failed executions to SQS)
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  # Add tags
  tags = {
    Environment = var.environment
  }
}

##############################
# Upload Lambda code to S3
##############################
resource "aws_s3_object" "lambda_zip" {
  bucket       = aws_s3_bucket.example.bucket
  key          = "lambda.zip"
  source       = var.lambda_zip_path  # Make sure this file exists locally in your working directory
  content_type = "application/zip"

  server_side_encryption = "AES256"
}

##############################
# S3 Event for Lambda
##############################
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.example.arn
  source_account = data.aws_caller_identity.current.account_id
}

# Connect S3 event to Lambda
resource "aws_s3_bucket_notification" "example" {
  bucket = aws_s3_bucket.example.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.example.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# SNS topic for notifications
resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts-topic"
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "security_alerts_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.security_email
}