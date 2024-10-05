# File: scripts/setup_aws.py

import boto3
import os
import logging
import time
from botocore.exceptions import ProfileNotFound, NoCredentialsError, ClientError
from dotenv import load_dotenv
import sys
from datetime import datetime, timedelta

# Load environment variables from .env file if present
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def setup_aws_credentials():
    """Set up AWS credentials using the specified profile."""
    # Get the AWS profile from environment variable
    aws_profile = os.environ.get('AWS_PROFILE') or os.environ.get('AWS_DEFAULT_PROFILE')
    
    if not aws_profile:
        logging.error("No AWS profile set. Please set the AWS_PROFILE or AWS_DEFAULT_PROFILE environment variable.")
        sys.exit(1)
    
    try:
        session = boto3.Session(profile_name=aws_profile)
        # Test the credentials by making a simple API call
        sts = session.client('sts')
        sts.get_caller_identity()
        logging.info(f"Successfully authenticated using AWS profile: {aws_profile}")
        return session
    except Exception as e:
        logging.error(f"Failed to authenticate with AWS using profile {aws_profile}. Error: {str(e)}")
        sys.exit(1)

def get_registered_nameservers(domain_name):
    """Get the registered nameservers for a domain."""
    client = boto3.client('route53domains')
    try:
        response = client.get_domain_detail(DomainName=domain_name)
        return sorted([ns['Name'] for ns in response['Nameservers']])
    except ClientError as e:
        logging.error(f"Error getting registered nameservers: {str(e)}")
        return []

def get_hosted_zone_nameservers(hosted_zone_id):
    """Get the nameservers for a hosted zone."""
    client = boto3.client('route53')
    try:
        response = client.get_hosted_zone(Id=hosted_zone_id)
        return sorted(response['DelegationSet']['NameServers'])
    except ClientError as e:
        logging.error(f"Error getting hosted zone nameservers: {str(e)}")
        return []

def check_pending_operations(domain_name):
    """Check and wait for pending operations on a domain."""
    client = boto3.client('route53domains')
    try:
        response = client.list_operations(
            SubmittedSince=datetime.now() - timedelta(days=30)
        )
        pending_ops = [op['OperationId'] for op in response['Operations'] if op['Status'] == 'IN_PROGRESS' and op['DomainName'] == domain_name]
        
        if pending_ops:
            logging.info(f"Pending operations found for {domain_name}. Waiting for completion...")
            waiter = client.get_waiter('operation_successful')
            for op_id in pending_ops:
                waiter.wait(OperationId=op_id)
            logging.info("Pending operations completed.")
    except ClientError as e:
        logging.error(f"Error checking pending operations: {str(e)}")

def update_registered_nameservers(domain_name, hosted_zone_nameservers):
    """Update the registered nameservers for a domain."""
    client = boto3.client('route53domains')
    max_retries = 5
    retry_delay = 30

    for attempt in range(max_retries):
        try:
            check_pending_operations(domain_name)
            client.update_domain_nameservers(
                DomainName=domain_name,
                Nameservers=[{'Name': ns} for ns in hosted_zone_nameservers]
            )
            logging.info(f"Updated registered nameservers for {domain_name}")
            return True
        except ClientError as e:
            logging.error(f"Failed to update nameservers: {str(e)}")
            if attempt < max_retries - 1:
                logging.info(f"Retrying in {retry_delay} seconds... (Attempt {attempt + 1} of {max_retries})")
                time.sleep(retry_delay)
                retry_delay *= 2
            else:
                logging.error(f"Failed to update nameservers after {max_retries} attempts.")
                return False

def create_or_get_hosted_zone(session, domain_name):
    """Create or get the Route53 hosted zone for the domain and sync nameservers."""
    client = session.client('route53')
    
    try:
        # Check if the hosted zone already exists
        hosted_zones = client.list_hosted_zones_by_name(DNSName=domain_name)['HostedZones']
        for zone in hosted_zones:
            if zone['Name'] == domain_name + '.':
                hosted_zone_id = zone['Id'].split('/')[-1]
                logging.info(f"Found existing hosted zone for {domain_name}")
                break
        else:
            # If not, create a new hosted zone
            response = client.create_hosted_zone(Name=domain_name, CallerReference=str(hash(domain_name)))
            hosted_zone_id = response['HostedZone']['Id'].split('/')[-1]
            logging.info(f"Created new hosted zone for {domain_name}")

        # Compare and update nameservers if necessary
        registered_ns = get_registered_nameservers(domain_name)
        hosted_zone_ns = get_hosted_zone_nameservers(hosted_zone_id)

        if set(registered_ns) != set(hosted_zone_ns):
            logging.info("Nameservers mismatch detected. Updating registered nameservers...")
            if update_registered_nameservers(domain_name, hosted_zone_ns):
                logging.info("Nameservers updated successfully.")
            else:
                logging.warning("Failed to update nameservers. Manual intervention may be required.")
        else:
            logging.info("Nameservers are already in sync.")

        return hosted_zone_id
    except ClientError as e:
        logging.error(f"Error working with Route53: {str(e)}")
        raise

def setup_aws(domain_name):
    """Set up AWS configuration and hosted zone."""
    session = setup_aws_credentials()
    hosted_zone_id = create_or_get_hosted_zone(session, domain_name)
    return hosted_zone_id

if __name__ == '__main__':
    domain_name = os.getenv('DOMAIN_NAME')
    if not domain_name:
        raise ValueError("DOMAIN_NAME environment variable is not set.")
    setup_aws(domain_name)
