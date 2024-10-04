#!/usr/bin/env python3

import os
import logging
import subprocess
import json
import boto3
import time

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def build_next_app():
    """Build the Next.js app."""
    app_dir = 'next-app'
    logging.info("Building Next.js app...")
    subprocess.run(['npm', 'run', 'build'], cwd=app_dir, check=True)
    logging.info("Next.js app built successfully.")

def get_terraform_outputs():
    """Get outputs from Terraform."""
    logging.info("Retrieving Terraform outputs...")
    output = subprocess.check_output(['terraform', 'output', '-json'], cwd='terraform')
    outputs = json.loads(output)
    return outputs['s3_bucket_name']['value'], outputs['cloudfront_distribution_id']['value']

def sync_s3_bucket(bucket_name, source_dir):
    """Sync the built Next.js app to the S3 bucket using AWS CLI."""
    logging.info(f"Syncing files from '{source_dir}' to S3 bucket '{bucket_name}'...")
    subprocess.run(['aws', 's3', 'sync', source_dir, f's3://{bucket_name}', '--delete', '--cache-control', 'no-store,max-age=0'], check=True)
    logging.info(f"Files synced to S3 bucket '{bucket_name}'.")

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

def update_site():
    """Main function to update the website."""
    app_dir = 'next-app'
    source_dir = os.path.join(app_dir, 'out')
    
    build_next_app()
    
    s3_bucket_name, distribution_id = get_terraform_outputs()
    sync_s3_bucket(s3_bucket_name, source_dir)
    invalidate_cloudfront(distribution_id)
    
    logging.info("Website updated successfully!")

if __name__ == '__main__':
    try:
        update_site()
    except Exception as e:
        logging.error(f"An error occurred during site update: {str(e)}")
        raise