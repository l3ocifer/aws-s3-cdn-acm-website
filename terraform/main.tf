provider "aws" {
  region = var.aws_region
}

data "aws_route53_zone" "existing" {
  name         = "${var.domain_name}."
  private_zone = false
}

resource "aws_route53_zone" "primary" {
  name = var.domain_name
  count = var.hosted_zone_exists ? 0 : 1
}

resource "aws_s3_bucket" "website" {
  bucket = var.domain_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "aws_s3_bucket_object" "website" {
  for_each = fileset(local.content_dir, "**")
  bucket   = aws_s3_bucket.website.bucket
  key      = each.value
  source   = "${local.content_dir}/${each.value}"
  acl      = "public-read"
}

resource "aws_route53_record" "website" {
  zone_id = var.hosted_zone_exists ? data.aws_route53_zone.existing[0].zone_id : aws_route53_zone.primary[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cert_validation" {
  zone_id = var.hosted_zone_exists ? data.aws_route53_zone.existing[0].zone_id : aws_route53_zone.primary[0].zone_id
  name    = aws_acm_certificate.website.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.website.domain_validation_options.0.resource_record_type
  ttl     = 60
  records = [aws_acm_certificate.website.domain_validation_options.0.resource_record_value]
}

resource "aws_acm_certificate" "website" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.domain_name
  }
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.domain_name}"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.website.arn
    ssl_support_method              = "sni-only"
    minimum_protocol_version        = "TLSv1.2_2021"
  }

  tags = {
    Name = var.domain_name
  }
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website.id
}

output "name_servers" {
  value = aws_route53_zone.primary[0].name_servers
}
