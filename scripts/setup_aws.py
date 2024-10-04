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
    aws_profile = os.getenv('AWS_PROFILE')
    aws_region = os.getenv('AWS_REGION')

    if not aws_profile:
        logging.error("AWS_PROFILE is not set. Please set it and try again.")
        raise ValueError("AWS_PROFILE is not set")

    try:
        session = boto3.Session(profile_name=aws_profile, region_name=aws_region)
        # Test if the credentials are valid
        sts_client = session.client('sts')
        sts_client.get_caller_identity()
        logging.info(f"Successfully authenticated with AWS using profile: {aws_profile}")
        if aws_region:
            logging.info(f"Using AWS region: {aws_region}")
        return session
    except ProfileNotFound:
        logging.error(f"AWS profile '{aws_profile}' not found. Please check your AWS configuration.")
        raise
    except NoCredentialsError:
        logging.error(f"No valid credentials found for profile '{aws_profile}'. Please check your AWS configuration.")
        raise
    except ClientError as e:
        logging.error(f"Error authenticating with AWS: {str(e)}")
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
