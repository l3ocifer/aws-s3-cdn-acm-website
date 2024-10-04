# File: scripts/setup_terraform.py

import subprocess
import os
import logging
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def update_backend_tf(bucket_name):
    """Update the backend.tf file with the correct bucket name."""
    backend_tf_path = 'terraform/backend.tf'
    with open(backend_tf_path, 'r') as f:
        content = f.read()
    
    updated_content = content.replace('YOUR_BUCKET_NAME', bucket_name)
    
    with open(backend_tf_path, 'w') as f:
        f.write(updated_content)
    logging.info("Updated terraform/backend.tf with the correct bucket name.")

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
    update_backend_tf(bucket_name)
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
