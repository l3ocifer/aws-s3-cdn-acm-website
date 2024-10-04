# File: scripts/setup_aws.py

import boto3
import os
import logging
from botocore.exceptions import ProfileNotFound, NoCredentialsError
from dotenv import load_dotenv

# Load environment variables from .env file if present
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def setup_aws_credentials():
    """Set up AWS credentials."""
    aws_profile = os.getenv('AWS_PROFILE', 'default')
    try:
        session = boto3.Session(profile_name=aws_profile)
        # Test if the credentials are valid
        session.client('sts').get_caller_identity()
        logging.info(f"Successfully authenticated with AWS using profile: {aws_profile}")
    except ProfileNotFound:
        logging.error(f"AWS profile '{aws_profile}' not found. Please run 'aws configure' to set up your credentials.")
        raise
    except NoCredentialsError:
        logging.error("No AWS credentials found. Please run 'aws configure' to set up your credentials.")
        raise
    except Exception as e:
        logging.error(f"Error authenticating with AWS: {str(e)}")
        raise

def create_or_get_hosted_zone(domain_name):
    """Create or get the Route53 hosted zone for the domain."""
    client = boto3.client('route53')
    
    # Check if the hosted zone already exists
    hosted_zones = client.list_hosted_zones_by_name(DNSName=domain_name)['HostedZones']
    for zone in hosted_zones:
        if zone['Name'] == domain_name + '.':
            logging.info(f"Found existing hosted zone for {domain_name}")
            return zone['Id'].split('/')[-1]
    
    # If not, create a new hosted zone
    response = client.create_hosted_zone(Name=domain_name, CallerReference=str(hash(domain_name)))
    logging.info(f"Created new hosted zone for {domain_name}")
    return response['HostedZone']['Id'].split('/')[-1]

def setup_aws(domain_name):
    """Set up AWS configuration and hosted zone."""
    setup_aws_credentials()
    hosted_zone_id = create_or_get_hosted_zone(domain_name)
    # Save hosted zone ID to file
    with open('.hosted_zone_id', 'w') as f:
        f.write(hosted_zone_id)
    return hosted_zone_id

if __name__ == '__main__':
    domain_name = os.getenv('DOMAIN_NAME')
    if not domain_name:
        raise ValueError("DOMAIN_NAME environment variable is not set.")
    setup_aws(domain_name)
