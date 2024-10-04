#!/usr/bin/env python3
# File: scripts/main.py

import os
import logging
import sys

# Set up logging
logging.basicConfig(level=logging.INFO)

def main():
    try:
        from setup_aws import setup_aws
        from setup_terraform import setup_terraform
        from setup_site import setup_site
        from deploy_website import deploy_website

        domain_name = os.getenv('DOMAIN_NAME')
        repo_name = os.getenv('REPO_NAME')
        
        if not domain_name or not repo_name:
            raise ValueError("DOMAIN_NAME and REPO_NAME environment variables must be set.")

        hosted_zone_id = setup_aws(domain_name)
        setup_terraform(f"{repo_name}-tf-state", domain_name, repo_name, hosted_zone_id)
        setup_site(domain_name)
        deploy_website()

        logging.info(f"Website setup and deployment complete for {domain_name}")
    except ImportError as e:
        logging.error(f"Failed to import required module: {e}")
        logging.error("Please ensure all required packages are installed in the virtual environment.")
        sys.exit(1)
    except Exception as e:
        logging.error(f"An error occurred during the setup process: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
