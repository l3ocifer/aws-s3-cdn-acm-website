#!/usr/bin/env python3
# File: scripts/main.py

import os
import logging
import sys
from botocore.exceptions import ProfileNotFound, NoCredentialsError, ClientError
from scripts.setup_aws import setup_aws
from scripts.setup_site import setup_site
from scripts.setup_terraform import setup_terraform
from scripts.deploy_website import deploy_website
from scripts.install_requirements import install_requirements

# Set up logging
logging.basicConfig(level=logging.INFO)

def main():
    try:
        # Install required dependencies
        install_requirements()

        domain_name = os.getenv('DOMAIN_NAME')
        repo_name = os.getenv('REPO_NAME')
        if not domain_name or not repo_name:
            raise ValueError("DOMAIN_NAME and REPO_NAME environment variables must be set.")
        logging.info(f"Using domain name: {domain_name}")
        logging.info(f"Using repository name: {repo_name}")

        try:
            hosted_zone_id = setup_aws(domain_name)
        except Exception as e:
            logging.error(f"AWS setup failed: {str(e)}")
            logging.error("Please ensure your AWS credentials are correctly configured.")
            logging.error("You can set them using environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY,")
            logging.error("or by running 'aws configure' to set up your AWS CLI profile.")
            logging.error(f"Current AWS profile: {os.environ.get('AWS_PROFILE', 'Not set')}")
            logging.error(f"Current AWS region: {os.environ.get('AWS_DEFAULT_REGION', 'Not set')}")
            raise

        # Set up Terraform and provision AWS infrastructure
        try:
            setup_terraform(domain_name, repo_name, hosted_zone_id)
        except Exception as e:
            logging.error(f"Failed to set up Terraform: {str(e)}")
            return

        # Set up and customize the Next.js site
        setup_site(domain_name)

        # Deploy the website
        deploy_website()

        logging.info("Website setup and deployment completed successfully!")
    except Exception as e:
        logging.error(f"An error occurred during setup: {str(e)}")

if __name__ == "__main__":
    main()
