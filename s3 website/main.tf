# main.tf
# AWS S3 static website with CloudFront and OAI

provider "aws" {
  region = var.aws_region
}

# S3 bucket for website content (now private)
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Website configuration still needed for directory indexes
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "website_bucket_acl_ownership" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "website_public_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create Origin Access Identity for CloudFront
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${var.bucket_name}"
}

# Bucket policy that allows CloudFront OAI access
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.oai.id}"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website_public_access]
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${var.bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  
  # Optional: Configure custom domain with SSL certificate
  # aliases = ["example.com", "www.example.com"]
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Optional: Configure SSL certificate if using custom domain
  # viewer_certificate {
  #   acm_certificate_arn = aws_acm_certificate.cert.arn
  #   ssl_support_method = "sni-only"
  #   minimum_protocol_version = "TLSv1.2_2019"
  # }

  # Use CloudFront default certificate for *.cloudfront.net domain
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Custom error response to handle SPA routing
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  tags = {
    Name        = "${var.bucket_name}-distribution"
    Environment = var.environment
  }
}

# Upload index.html - removed ACL since bucket is now private
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  content      = file("${path.module}/website/index.html")
  content_type = "text/html"
}

# Upload styles.css
resource "aws_s3_object" "styles" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "styles.css"
  content      = file("${path.module}/website/styles.css")
  content_type = "text/css"
}

# Upload script.js 
resource "aws_s3_object" "script" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "script.js"
  content      = file("${path.module}/website/script.js")
  content_type = "application/javascript"
}

# Upload error.html 
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "error.html"
  content      = file("${path.module}/website/error.html")
  content_type = "text/html"
}

# Output values
output "website_bucket_name" {
  value = aws_s3_bucket.website_bucket.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.website_distribution.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website_distribution.id
}