# File: scripts/main.py

import os
import logging
from dotenv import load_dotenv

# Import functions from other scripts
from install_requirements import install_requirements
from setup_aws import setup_aws
from setup_terraform import setup_terraform
from setup_site import setup_site
from deploy_website import deploy_website

# Set up logging
logging.basicConfig(level=logging.INFO)

def main():
    """Main function to orchestrate the website setup and deployment."""
    # Load environment variables from .env
    load_dotenv()
    
    # Get domain name from environment variable
    domain_name = os.getenv('DOMAIN_NAME')
    if not domain_name:
        domain_name = input("Enter the domain name: ")
        os.environ['DOMAIN_NAME'] = domain_name
    repo_name = domain_name.replace('.', '-')
    os.environ['REPO_NAME'] = repo_name
    
    # Install requirements
    install_requirements()
    
    # Set up AWS and get hosted zone ID
    hosted_zone_id = setup_aws(domain_name)
    os.environ['HOSTED_ZONE_ID'] = hosted_zone_id
    
    # Set up Terraform
    setup_terraform(f"{repo_name}-tf-state", domain_name, repo_name, hosted_zone_id)
    
    # Set up the Next.js site
    setup_site(domain_name)
    
    # Deploy the website
    deploy_website()
    
    logging.info(f"Website setup complete. Your site should be accessible at https://{domain_name}")

if __name__ == '__main__':
    main()
