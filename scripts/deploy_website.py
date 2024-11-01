# File: scripts/deploy_website.py

import boto3
import os
import logging
import subprocess
import time
import json
from botocore.exceptions import ClientError
import hashlib

# Set up logging
logging.basicConfig(level=logging.INFO)

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

def get_terraform_outputs():
    """Get outputs from Terraform."""
    logging.info("Retrieving Terraform outputs...")
    output = subprocess.check_output(['terraform', 'output', '-json'], cwd='terraform')
    outputs = json.loads(output)
    return outputs['s3_bucket_name']['value'], outputs['cloudfront_distribution_id']['value']

def build_next_app(app_dir):
    """Build the Next.js app."""
    logging.info("Building Next.js app...")
    subprocess.run(['npm', 'run', 'build'], cwd=app_dir, check=True)

def deploy_website():
    """Deploy the website to AWS."""
    app_dir = 'next-app'
    source_dir = os.path.join(app_dir, 'out')
    
    try:
        # Get current site hash before building
        old_hash = get_site_hash(source_dir) if os.path.exists(source_dir) else None
        
        # Build the site
        build_next_app(app_dir)
        
        # Get new site hash
        new_hash = get_site_hash(source_dir)
        
        # Only deploy if hashes differ or old hash doesn't exist
        if old_hash != new_hash:
            s3_bucket_name, distribution_id = get_terraform_outputs()
            sync_s3_bucket(s3_bucket_name, source_dir)
            invalidate_cloudfront(distribution_id)
            logging.info("Website deployed successfully with new changes.")
        else:
            logging.info("No changes detected in the site content. Skipping deployment.")
    except Exception as e:
        logging.error(f"Deployment failed: {str(e)}")
        raise

def get_site_hash(directory):
    """Calculate hash of the site contents."""
    if not os.path.exists(directory):
        return None
        
    file_hashes = {}
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            with open(file_path, 'rb') as f:
                file_hash = hashlib.md5(f.read()).hexdigest()
            rel_path = os.path.relpath(file_path, directory)
            file_hashes[rel_path] = file_hash
    
    # Create a deterministic string from the dictionary
    content_str = json.dumps(file_hashes, sort_keys=True)
    return hashlib.md5(content_str.encode()).hexdigest()

if __name__ == '__main__':
    deploy_website()
