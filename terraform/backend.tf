terraform {
  backend "s3" {
    bucket = "DOMAIN_NAME_PLACEHOLDER-tf-state"
    key    = "terraform/state"
    region = "us-east-1"
  }
}