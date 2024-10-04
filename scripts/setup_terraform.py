# File: scripts/setup_terraform.py

import boto3
import subprocess
import os
import logging
from botocore.exceptions import ClientError
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def create_backend_bucket(bucket_name):
    """Create an S3 bucket for Terraform backend if it doesn't exist."""
    s3 = boto3.client('s3')
    region = boto3.session.Session().region_name
    
    try:
        s3.head_bucket(Bucket=bucket_name)
        logging.info(f"S3 bucket '{bucket_name}' already exists.")
    except botocore.exceptions.ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == '404':
            try:
                if region == 'us-east-1':
                    s3.create_bucket(Bucket=bucket_name)
                else:
                    s3.create_bucket(
                        Bucket=bucket_name,
                        CreateBucketConfiguration={'LocationConstraint': region}
                    )
                logging.info(f"Created S3 bucket '{bucket_name}' for Terraform backend.")
            except botocore.exceptions.ClientError as create_error:
                logging.error(f"Failed to create S3 bucket: {str(create_error)}")
                raise
        else:
            logging.error(f"Error checking S3 bucket: {str(e)}")
            raise

def generate_backend_tf(bucket_name):
    """Generate the backend.tf file with the correct bucket name."""
    backend_tf_content = f"""
terraform {{
  backend "s3" {{
    bucket = "{bucket_name}"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }}
}}
"""
    with open('terraform/backend.tf', 'w') as f:
        f.write(backend_tf_content)
    logging.info("Generated terraform/backend.tf")

def generate_tfvars(domain_name, repo_name, hosted_zone_id):
    """Generate terraform.tfvars file with the necessary variables."""
    tfvars_content = f"""
domain_name   = "{domain_name}"
repo_name     = "{repo_name}"
hosted_zone_id = "{hosted_zone_id}"
"""
    with open('terraform/terraform.tfvars', 'w') as f:
        f.write(tfvars_content)
    logging.info("Generated terraform/terraform.tfvars")

def init_terraform():
    """Initialize Terraform."""
    subprocess.run(['terraform', 'init'], cwd='terraform', check=True)
    logging.info("Initialized Terraform.")

def apply_terraform():
    """Apply the Terraform configuration."""
    subprocess.run(['terraform', 'apply', '-auto-approve'], cwd='terraform', check=True)
    logging.info("Applied Terraform configuration.")

def setup_terraform(bucket_name, domain_name, repo_name, hosted_zone_id):
    """Set up Terraform configuration."""
    # Sanitize bucket name
    bucket_name = bucket_name.lower().replace('_', '-')
    
    create_backend_bucket(bucket_name)
    generate_backend_tf(bucket_name)
    generate_tfvars(domain_name, repo_name, hosted_zone_id)
    init_terraform()
    apply_terraform()

if __name__ == '__main__':
    domain_name = os.getenv('DOMAIN_NAME')
    repo_name = os.getenv('REPO_NAME')
    hosted_zone_id = os.getenv('HOSTED_ZONE_ID')
    if not domain_name or not repo_name or not hosted_zone_id:
        raise ValueError("DOMAIN_NAME, REPO_NAME, and HOSTED_ZONE_ID environment variables must be set.")
    bucket_name = f"{repo_name}-tf-state"
    setup_terraform(bucket_name, domain_name, repo_name, hosted_zone_id)
