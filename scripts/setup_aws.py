# File: scripts/setup_aws.py

import boto3
import os
import logging
from botocore.exceptions import NoCredentialsError, ClientError
from dotenv import load_dotenv

# Load environment variables from .env file if present
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def setup_aws_credentials():
    """Check if AWS credentials are configured properly."""
    aws_profile = os.getenv('AWS_PROFILE', 'default')
    os.environ['AWS_PROFILE'] = aws_profile
    session = boto3.Session(profile_name=aws_profile)
    sts = session.client('sts')
    try:
        identity = sts.get_caller_identity()
        logging.info(f"AWS credentials are valid for profile '{aws_profile}'.")
        logging.info(f"Account: {identity['Account']}")
    except (NoCredentialsError, ClientError) as e:
        logging.error("AWS credentials are not configured properly.")
        raise e

def create_or_get_hosted_zone(domain_name):
    """Create or get the hosted zone for the domain."""
    route53 = boto3.client('route53')
    # Check for existing hosted zone
    zones = route53.list_hosted_zones_by_name(DNSName=domain_name)
    for zone in zones['HostedZones']:
        if zone['Name'] == f"{domain_name}.":
            logging.info(f"Found existing hosted zone '{zone['Id']}' for domain '{domain_name}'.")
            return zone['Id']
    # Create new hosted zone
    logging.info(f"Creating new hosted zone for domain '{domain_name}'.")
    response = route53.create_hosted_zone(
        Name=domain_name,
        CallerReference=str(hash(domain_name))
    )
    zone_id = response['HostedZone']['Id']
    logging.info(f"Created hosted zone '{zone_id}' for domain '{domain_name}'.")
    return zone_id

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
