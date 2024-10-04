# File: terraform/outputs.tf

output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.website_bucket.id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website_distribution.id
}

output "website_url" {
  value       = "https://${var.domain_name}"
  description = "The URL of the website."
}
