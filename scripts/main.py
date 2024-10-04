#!/usr/bin/env python3
# File: scripts/main.py

import os
import logging
import sys
from botocore.exceptions import ProfileNotFound, NoCredentialsError, ClientError
from scripts.setup_aws import setup_aws
from scripts.setup_site import setup_site
from scripts.utils import get_domain_name

# Set up logging
logging.basicConfig(level=logging.INFO)

def main():
    try:
        domain_name = get_domain_name()
        logging.info(f"Using domain name: {domain_name}")

        try:
            hosted_zone_id = setup_aws(domain_name)
        except Exception as e:
            logging.error(f"AWS setup failed: {str(e)}")
            logging.error("Please ensure your AWS credentials are correctly configured.")
            logging.error("You can set them using environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY,")
            logging.error("or by running 'aws configure' to set up your AWS CLI profile.")
            return

        setup_site(domain_name, hosted_zone_id)
        logging.info("Website setup completed successfully!")
    except Exception as e:
        logging.error(f"An error occurred during setup: {str(e)}")

if __name__ == "__main__":
    main()
