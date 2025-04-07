# Provider Block
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}


##############################
# SSM Parameter Store for Database Password
resource "aws_ssm_parameter" "secret" {
  name        = "/production/database/password/master"
  description = "The parameter description"
  type        = "SecureString"
  value       = var.database_master_password
  key_id      = aws_kms_key.parameter_key.key_id  # Use a dedicated KMS key

  tags = {
    environment = "production"
  }
}

# KMS key for SSM Parameter encryption
resource "aws_kms_key" "parameter_key" {
  description             = "KMS key for encrypting SSM parameters"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    environment = "production"
  }
}

resource "aws_kms_alias" "parameter_key_alias" {
  name          = "alias/ssm-parameter-key"
  target_key_id = aws_kms_key.parameter_key.key_id
}

######################
# DynamoDB Table Resource with encryption
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

  # Enable server-side encryption
  server_side_encryption {
    enabled = true
  }

  # Enable point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    environment = "production"
  }
}

######################
# IAM Role for Lambda
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
}

# Add IAM policy to allow Lambda to access SSM Parameter Store and DynamoDB
resource "aws_iam_role_policy" "lambda_ssm_dynamodb_policy" {
  name = "lambda-ssm-dynamodb-access-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "ssm:GetParameter",
        Effect   = "Allow",
        Resource = "arn:aws:ssm:us-east-1:${var.aws_account_id}:parameter/production/database/password/master"
      },
      {
        Action   = [
          "dynamodb:PutItem",
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.example.arn
      },
      {
        Action   = [
          "kms:Decrypt"
        ],
        Effect   = "Allow",
        Resource = aws_kms_key.parameter_key.arn
      }
    ]
  })
}

# Add CloudWatch Logs permissions
resource "aws_iam_role_policy" "lambda_logging" {
  name   = "lambda-logging-policy"
  role   = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:${var.aws_account_id}:*"
      }
    ]
  })
}

######################
# Lambda function
resource "aws_lambda_function" "example" {
  function_name = "dynamodb-lambda"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "python3.9"

  # Reference Lambda code from the S3 bucket
  s3_bucket = aws_s3_bucket.example.bucket
  s3_key    = "lambda.zip"

  environment {
    variables = {
      ##################### Don't include secrets in environment variables #####################
      ##################### Instead, access them at runtime with AWS SDK #####################
      TABLE_NAME = aws_dynamodb_table.example.name
      SSM_PARAM_NAME = aws_ssm_parameter.secret.name
    }
  }

  depends_on = [aws_s3_object.lambda_zip]
}

######################
# S3 Bucket for Lambda code with enhanced security
resource "aws_s3_bucket" "example" {
  bucket = "my-lambda-trigger-bucket-${random_id.bucket_suffix.hex}"
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

# Enable server-side encryption
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

# Set up access logging
resource "aws_s3_bucket" "log_bucket" {
  bucket = "access-logs-${random_id.bucket_suffix.hex}"
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

resource "aws_s3_bucket_logging" "example" {
  bucket = aws_s3_bucket.example.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "access-logs/"
}

######################
# Upload Lambda code to S3
resource "aws_s3_object" "lambda_zip" {
  bucket       = aws_s3_bucket.example.bucket
  key          = "lambda.zip"
  source       = "lambda.zip"  # Make sure this file exists locally in your working directory
  content_type = "application/zip"
}

######################
# Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.example.arn
}

# Connect S3 event to Lambda
resource "aws_s3_bucket_notification" "example" {
  bucket = aws_s3_bucket.example.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.example.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
 ##
  # terraform apply -var="database_master_password=your_secure_password"