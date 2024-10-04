# File: scripts/setup_aws.py

import boto3
import os
import logging
from botocore.exceptions import ProfileNotFound, NoCredentialsError, ClientError
from dotenv import load_dotenv

# Load environment variables from .env file if present
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def setup_aws_credentials():
    """Set up AWS credentials using the specified profile."""
    # Get the AWS profile from environment variable, fallback to 'default' if not set
    aws_profile = os.environ.get('AWS_PROFILE') or os.environ.get('AWS_DEFAULT_PROFILE', 'default')
    
    try:
        session = boto3.Session(profile_name=aws_profile)
        # Test the credentials by making a simple API call
        sts = session.client('sts')
        sts.get_caller_identity()
        logging.info(f"Successfully authenticated using AWS profile: {aws_profile}")
    except Exception as e:
        logging.error(f"Failed to authenticate with AWS using profile {aws_profile}. Error: {str(e)}")
        raise

def create_or_get_hosted_zone(session, domain_name):
    """Create or get the Route53 hosted zone for the domain."""
    client = session.client('route53')
    
    try:
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
    except ClientError as e:
        logging.error(f"Error working with Route53: {str(e)}")
        raise

def setup_aws(domain_name):
    """Set up AWS configuration and hosted zone."""
    session = setup_aws_credentials()
    hosted_zone_id = create_or_get_hosted_zone(session, domain_name)
    # Save hosted zone ID to file
    with open('.hosted_zone_id', 'w') as f:
        f.write(hosted_zone_id)
    return hosted_zone_id

if __name__ == '__main__':
    domain_name = os.getenv('DOMAIN_NAME')
    if not domain_name:
        raise ValueError("DOMAIN_NAME environment variable is not set.")
    setup_aws(domain_name)
