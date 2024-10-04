# File: terraform/backend.tf

terraform {
  backend "s3" {
    bucket = "YOUR_BUCKET_NAME"  # This will be replaced by setup_terraform.py
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "YOUR_BUCKET_NAME"  # This will be replaced by setup_terraform.py

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
