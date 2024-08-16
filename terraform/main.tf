provider "aws" {
  region = "us-east-1"
}

variable "domain_name" {
  type = string
}

variable "repo_name" {
  type = string
}

variable "acm_cert_exists" {
  type = bool
}

variable "hosted_zone_id" {
  type = string
  default = ""
}

data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  private_zone = false

  count = var.hosted_zone_id == "" ? 1 : 0
}

locals {
  zone_id = var.hosted_zone_id != "" ? var.hosted_zone_id : try(data.aws_route53_zone.main[0].zone_id, "")
  zone_name = var.hosted_zone_id != "" ? var.domain_name : try(data.aws_route53_zone.main[0].name, "")
}

resource "aws_route53_zone" "main" {
  name = local.zone_name

  count = var.hosted_zone_id == "" ? 1 : 0
}

resource "aws_s3_bucket" "website" {
  bucket = var.repo_name
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "404.html"
  }
}

resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${var.domain_name}"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]
  default_cache_behavior {
    target_origin_id       = "S3-${var.domain_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn      = var.acm_cert_exists ? data.aws_acm_certificate.existing[0].arn : aws_acm_certificate.cert[0].arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_route53_record" "website" {
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "cert" {
  count             = var.acm_cert_exists ? 0 : 1
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_acm_certificate" "existing" {
  count       = var.acm_cert_exists ? 1 : 0
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_route53_record" "cert_validation" {
  count   = var.acm_cert_exists ? 0 : 1
  name    = tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_type
  zone_id = local.zone_id
  records = [tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  count                   = var.acm_cert_exists ? 0 : 1
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation[0].fqdn]
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website_distribution.id
}

output "name_servers" {
  value = var.hosted_zone_id != "" ? [] : try(aws_route53_zone.main[0].name_servers, [])
}