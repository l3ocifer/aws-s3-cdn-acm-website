terraform {
  backend "s3" {
    bucket = "${var.domain_name}-tf-state"
    key    = "terraform/state"
    region = "us-east-1"
  }
}
