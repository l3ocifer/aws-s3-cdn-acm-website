# File: scripts/setup_terraform.py

import subprocess
import os
import logging
import boto3
import time
import re

# Set up logging
logging.basicConfig(level=logging.INFO)

def generate_tfvars(domain_name, repo_name, hosted_zone_id, account_id, website_bucket_name):
    """Generate terraform.tfvars file with the necessary variables."""
    tfvars_content = f"""
domain_name   = "{domain_name}"
repo_name     = "{repo_name}"
hosted_zone_id = "{hosted_zone_id}"
account_id    = "{account_id}"
website_bucket_name = "{website_bucket_name}"
"""
    with open('terraform/terraform.tfvars', 'w') as f:
        f.write(tfvars_content)
    logging.info("Generated terraform/terraform.tfvars")

def init_and_apply(tf_state_bucket_name):
    """Initialize and apply Terraform configuration."""
    backend_config = f"-backend-config=bucket={tf_state_bucket_name} -backend-config=key=terraform.tfstate -backend-config=region=us-east-1"
    subprocess.run(['terraform', 'init', '-reconfigure'] + backend_config.split(), cwd='terraform', check=True)
    subprocess.run(['terraform', 'apply', '-auto-approve'], cwd='terraform', check=True)
    logging.info("Applied Terraform configuration.")

def create_s3_bucket(bucket_name):
    """Create an S3 bucket for Terraform state if it doesn't exist."""
    s3 = boto3.client('s3')
    
    # Ensure bucket name is valid
    bucket_name = bucket_name.lower()
    bucket_name = re.sub(r'[^a-z0-9-]', '-', bucket_name)  # Replace invalid characters with hyphens
    bucket_name = bucket_name[:63]  # Truncate to 63 characters if longer
    
    try:
        s3.head_bucket(Bucket=bucket_name)
        logging.info(f"S3 bucket '{bucket_name}' already exists.")
    except:
        try:
            s3.create_bucket(Bucket=bucket_name)
            logging.info(f"Created S3 bucket '{bucket_name}' for Terraform state.")
            # Wait for the bucket to be available
            waiter = s3.get_waiter('bucket_exists')
            waiter.wait(Bucket=bucket_name)
            logging.info(f"S3 bucket '{bucket_name}' is now available.")
        except Exception as e:
            logging.error(f"Failed to create S3 bucket: {str(e)}")
            raise
    return bucket_name

def setup_terraform(domain_name, repo_name, hosted_zone_id):
    """Set up Terraform configuration."""
    # Get AWS account ID
    sts = boto3.client('sts')
    account_id = sts.get_caller_identity()["Account"]
    
    # Create bucket names
    tf_state_bucket_name = f"tf-state-{repo_name}-{account_id}"
    tf_state_bucket_name = create_s3_bucket(tf_state_bucket_name)
    website_bucket_name = f"website-{re.sub(r'[^a-z0-9-]', '-', repo_name.lower())}-{account_id}"
    
    generate_tfvars(domain_name, repo_name, hosted_zone_id, account_id, website_bucket_name)
    init_and_apply(tf_state_bucket_name)

if __name__ == '__main__':
    domain_name = os.getenv('DOMAIN_NAME')
    repo_name = os.getenv('REPO_NAME')
    hosted_zone_id = os.getenv('HOSTED_ZONE_ID')
    if not domain_name or not repo_name or not hosted_zone_id:
        raise ValueError("DOMAIN_NAME, REPO_NAME, and HOSTED_ZONE_ID environment variables must be set.")
    setup_terraform(domain_name, repo_name, hosted_zone_id)
