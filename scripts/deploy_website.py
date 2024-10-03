# File: scripts/deploy_website.py

import boto3
import os
import logging
import subprocess
import time
import json
from botocore.exceptions import ClientError
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def sync_s3_bucket(bucket_name, source_dir):
    """Sync the built Next.js app to the S3 bucket."""
    s3 = boto3.client('s3')
    logging.info(f"Uploading files from '{source_dir}' to S3 bucket '{bucket_name}'...")
    for root, dirs, files in os.walk(source_dir):
        for file in files:
            local_path = os.path.join(root, file)
            s3_key = os.path.relpath(local_path, source_dir)
            s3.upload_file(local_path, bucket_name, s3_key)
    logging.info(f"Files uploaded to S3 bucket '{bucket_name}'.")

def invalidate_cloudfront(distribution_id):
    """Invalidate the CloudFront distribution to refresh content."""
    cf = boto3.client('cloudfront')
    caller_reference = str(time.time())
    logging.info(f"Creating invalidation for CloudFront distribution '{distribution_id}'...")
    invalidation = cf.create_invalidation(
        DistributionId=distribution_id,
        InvalidationBatch={
            'Paths': {'Quantity': 1, 'Items': ['/*']},
            'CallerReference': caller_reference
        }
    )
    logging.info(f"Invalidation '{invalidation['Invalidation']['Id']}' created.")

def get_terraform_outputs():
    """Get outputs from Terraform."""
    logging.info("Retrieving Terraform outputs...")
    output = subprocess.check_output(['terraform', 'output', '-json'], cwd='terraform')
    outputs = json.loads(output)
    s3_bucket_name = outputs['s3_bucket_name']['value']
    cloudfront_distribution_id = outputs['cloudfront_distribution_id']['value']
    return s3_bucket_name, cloudfront_distribution_id

def deploy_website():
    """Deploy the website to AWS."""
    s3_bucket_name = os.getenv('REPO_NAME')
    source_dir = 'next-app/out'
    sync_s3_bucket(s3_bucket_name, source_dir)
    # Get CloudFront distribution ID
    _, distribution_id = get_terraform_outputs()
    invalidate_cloudfront(distribution_id)
    logging.info("Website deployed successfully.")

if __name__ == '__main__':
    deploy_website()
