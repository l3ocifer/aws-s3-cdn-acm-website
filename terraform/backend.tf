# File: terraform/backend.tf

terraform {
  backend "s3" {
    bucket = "YOUR_BUCKET_NAME"  # This will be replaced by setup_terraform.py
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
