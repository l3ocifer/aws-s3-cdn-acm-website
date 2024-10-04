# File: terraform/variables.tf

variable "domain_name" {
  description = "The domain name for the website"
  type        = string
}

variable "repo_name" {
  description = "The name of the GitHub repository"
  type        = string
}

variable "hosted_zone_id" {
  description = "The ID of the Route53 hosted zone"
  type        = string
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
}

variable "website_bucket_name" {
  description = "The name of the S3 bucket for the website"
  type        = string
}
