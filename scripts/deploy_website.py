# File: scripts/deploy_website.py

import boto3
import os
import logging
import subprocess
import time
import json
from botocore.exceptions import ClientError
import hashlib
import traceback

# Set up logging
logging.basicConfig(level=logging.INFO)

def sync_s3_bucket(bucket_name, source_dir):
    """Sync the built Next.js app to the S3 bucket using AWS CLI."""
    aws_profile = os.environ.get('AWS_PROFILE')
    if not aws_profile:
        raise ValueError("AWS_PROFILE environment variable must be set")
    logging.info(f"Syncing files from '{source_dir}' to S3 bucket '{bucket_name}' using profile '{aws_profile}'...")
    subprocess.run(['aws', '--profile', aws_profile, 's3', 'sync', source_dir, f's3://{bucket_name}', '--delete', '--cache-control', 'no-store,max-age=0'], check=True)
    logging.info(f"Files synced to S3 bucket '{bucket_name}'.")

def invalidate_cloudfront(distribution_id):
    """Invalidate the CloudFront distribution to refresh content."""
    try:
        aws_profile = os.environ.get('AWS_PROFILE')
        if not aws_profile:
            raise ValueError("AWS_PROFILE environment variable must be set")
        
        # Initialize boto3 with explicit configuration
        session = boto3.Session(profile_name=aws_profile)
        from botocore.config import Config
        config = Config(
            region_name='us-east-1',
            retries=dict(
                max_attempts=3,
                mode='standard'
            )
        )
        
        cf = session.client(
            'cloudfront',
            config=config,
            region_name='us-east-1'
        )
        
        caller_reference = str(time.time())
        logging.info(f"Creating invalidation for CloudFront distribution '{distribution_id}' using profile '{aws_profile}'...")
        invalidation = cf.create_invalidation(
            DistributionId=distribution_id,
            InvalidationBatch={
                'Paths': {'Quantity': 1, 'Items': ['/*']},
                'CallerReference': caller_reference
            }
        )
        logging.info(f"Invalidation created with ID: {invalidation['Invalidation']['Id']}")
    except Exception as e:
        logging.error(f"Failed to create CloudFront invalidation: {str(e)}")
        logging.error(f"Detailed error: {traceback.format_exc()}")
        raise

def get_terraform_outputs():
    """Get outputs from Terraform."""
    logging.info("Retrieving Terraform outputs...")
    output = subprocess.check_output(['terraform', 'output', '-json'], cwd='terraform')
    outputs = json.loads(output)
    return outputs['s3_bucket_name']['value'], outputs['cloudfront_distribution_id']['value']

def deploy_website():
    """Deploy the website to AWS."""
    app_dir = 'next-app'
    source_dir = os.path.join(app_dir, 'out')
    hash_file = '.site-hash'
    
    try:
        s3_bucket_name, distribution_id = get_terraform_outputs()
        
        # Get new content hash
        new_hash = get_site_hash(source_dir)
        if not new_hash:
            raise ValueError("No built site content found in 'next-app/out'")
        
        # Always deploy if hash file doesn't exist (first deployment)
        if not os.path.exists(hash_file):
            logging.info("First deployment detected. Deploying site...")
            sync_s3_bucket(s3_bucket_name, source_dir)
            invalidate_cloudfront(distribution_id)
            
            # Save new hash
            with open(hash_file, 'w') as f:
                f.write(new_hash)
            
            # Commit changes to git
            try:
                subprocess.run(['git', 'add', hash_file], check=True)
                subprocess.run(['git', 'commit', '-m', 'update site hash'], check=True)
                subprocess.run(['git', 'push'], check=True)
                logging.info("Site hash committed and pushed to repository.")
            except subprocess.CalledProcessError as e:
                logging.warning(f"Failed to commit site hash: {str(e)}")
            
            logging.info("Website deployed successfully.")
            return
        
        # For subsequent deployments, check for changes
        with open(hash_file, 'r') as f:
            old_hash = f.read().strip()
        
        if old_hash != new_hash:
            logging.info("Changes detected. Deploying updates...")
            sync_s3_bucket(s3_bucket_name, source_dir)
            invalidate_cloudfront(distribution_id)
            
            # Update hash
            with open(hash_file, 'w') as f:
                f.write(new_hash)
            
            # Commit changes to git
            try:
                subprocess.run(['git', 'add', hash_file], check=True)
                subprocess.run(['git', 'commit', '-m', 'update site hash'], check=True)
                subprocess.run(['git', 'push'], check=True)
                logging.info("Site hash committed and pushed to repository.")
            except subprocess.CalledProcessError as e:
                logging.warning(f"Failed to commit site hash: {str(e)}")
            
            logging.info("Website deployed successfully.")
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
