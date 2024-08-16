#!/usr/bin/env bash

set -euo pipefail

deploy_website() {
    if [ ! -f .domain ]; then
        echo "ERROR: Domain file (.domain) not found. Please run createwebsite.sh first." >&2
        exit 1
    fi
    DOMAIN_NAME=$(cat .domain)
    REPO_NAME=$(echo "$DOMAIN_NAME" | sed -E 's/\.[^.]+$//')
    
    # Check if the public directory exists
    if [ ! -d "public" ]; then
        echo "ERROR: 'public' directory not found. Make sure the website has been built." >&2
        exit 1
    fi

    echo "Syncing website to S3..."
    if ! aws s3 sync public "s3://${REPO_NAME}" --delete --cache-control "max-age=31536000,public,immutable" --exclude "*.html"; then
        echo "ERROR: Failed to sync website to S3" >&2
        exit 1
    fi
    if ! aws s3 sync public "s3://${REPO_NAME}" --delete --cache-control "no-cache" --include "*.html"; then
        echo "ERROR: Failed to sync HTML files to S3" >&2
        exit 1
    fi

    # Invalidate CloudFront cache
    echo "Invalidating CloudFront cache..."
    DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Aliases.Items[?contains(@,'${DOMAIN_NAME}')]].Id" --output text)
    
    if [ -z "$DISTRIBUTION_ID" ]; then
        echo "ERROR: CloudFront distribution not found for ${DOMAIN_NAME}" >&2
        exit 1
    fi

    INVALIDATION_ID=$(aws cloudfront create-invalidation --distribution-id ${DISTRIBUTION_ID} --paths "/*" --query 'Invalidation.Id' --output text)
    
    if [ -z "$INVALIDATION_ID" ]; then
        echo "ERROR: Failed to create CloudFront invalidation" >&2
        exit 1
    fi

    echo "CloudFront invalidation created. Invalidation ID: ${INVALIDATION_ID}"

    # Wait for invalidation to complete
    echo "Waiting for CloudFront invalidation to complete..."
    if ! aws cloudfront wait invalidation-completed --distribution-id ${DISTRIBUTION_ID} --id ${INVALIDATION_ID}; then
        echo "WARNING: CloudFront invalidation did not complete in the expected time. It may still be in progress." >&2
    else
        echo "CloudFront invalidation completed successfully."
    fi

    echo "Website deployed successfully!"
}

deploy_website