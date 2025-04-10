# main.tf
# AWS S3 static website with CloudFront and enhanced security controls

provider "aws" {
  region = var.aws_region
}

# S3 bucket for website content (private)
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Website configuration for directory indexes
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Enable server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "website_encryption" {
  bucket = aws_s3_bucket.website_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
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





# Create Origin Access Control for CloudFront (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for ${var.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy that allows CloudFront OAC access
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website_distribution.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website_public_access]
}

# CloudFront cache policy
resource "aws_cloudfront_cache_policy" "cache_policy" {
  name        = "${var.bucket_name}-cache-policy"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1
  
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# CloudFront origin request policy
resource "aws_cloudfront_origin_request_policy" "origin_request_policy" {
  name = "${var.bucket_name}-origin-request-policy"
  
  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "none"
  }
  query_strings_config {
    query_string_behavior = "none"
  }
}





# CloudFront distribution with enhanced security
resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
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

    # Use cache and origin request policies instead of forwarded_values
    cache_policy_id          = aws_cloudfront_cache_policy.cache_policy.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.origin_request_policy.id

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Use CloudFront default certificate with modern TLS
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    
    # Optional: For custom domain with ACM certificate
    # acm_certificate_arn      = aws_acm_certificate.cert.arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "CH"]
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

# Upload index.html
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
  description = "Name of the S3 bucket hosting the website content"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.website_distribution.domain_name
  description = "Domain name of the CloudFront distribution"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website_distribution.id
  description = "ID of the CloudFront distribution"
}
