# main.tf
# AWS S3 static website with CORS enabled

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_cors_configuration" "website_cors" {
  bucket = aws_s3_bucket.website_bucket.id

cors_rule {
  allowed_headers = ["*"]
  allowed_methods = ["GET", "HEAD"]
  allowed_origins = ["*"]  # Start with wildcard for testing
  max_age_seconds = 3000
}
  }

resource "aws_s3_bucket_ownership_controls" "website_bucket_acl_ownership" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "website_public_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "website_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.website_bucket_acl_ownership,
    aws_s3_bucket_public_access_block.website_public_access,
  ]

  bucket = aws_s3_bucket.website_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website_public_access]
}

# Upload index.html
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  content      = file("${path.module}/website/index.html")
  content_type = "text/html"
  acl          = "public-read"

  depends_on = [aws_s3_bucket_acl.website_bucket_acl]
}

# Upload styles.css
resource "aws_s3_object" "styles" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "styles.css"
  content      = file("${path.module}/website/styles.css")
  content_type = "text/css"
  acl          = "public-read"

  depends_on = [aws_s3_bucket_acl.website_bucket_acl]
}

# Upload script.js
resource "aws_s3_object" "script" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "script.js"
  content      = file("${path.module}/website/script.js")
  content_type = "application/javascript"
  acl          = "public-read"

  depends_on = [aws_s3_bucket_acl.website_bucket_acl]
}

# Upload error.html
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "error.html"
  content      = file("${path.module}/website/error.html")
  content_type = "text/html"
  acl          = "public-read"

  depends_on = [aws_s3_bucket_acl.website_bucket_acl]
}

# Output values
output "website_bucket_name" {
  value = aws_s3_bucket.website_bucket.id
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.website_config.website_endpoint
}