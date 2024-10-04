# File: terraform/backend.tf

terraform {
  backend "s3" {
    bucket = "tf-state-placeholder"  # This will be replaced by setup_terraform.py
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
