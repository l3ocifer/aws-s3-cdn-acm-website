# File: terraform/variables.tf

variable "domain_name" {
  description = "The domain name for the website"
  type        = string
}

variable "repo_name" {
  description = "The repository name, used for S3 bucket name"
  type        = string
}

variable "hosted_zone_id" {
  description = "The ID of the Route53 hosted zone"
  type        = string
}
