#!/usr/bin/env bash

set -euo pipefail

# Import logging functions
source ./scripts/logging.sh

deploy_website() {
    if [ ! -f .domain ]; then
        error "Domain file (.domain) not found. Please run createwebsite.sh first."
    fi
    DOMAIN_NAME=$(cat .domain)
    REPO_NAME=$(echo "$DOMAIN_NAME" | sed -E 's/\.[^.]+$//')
    
    # Check if the public directory exists
    if [ ! -d "public" ]; then
        error "'public' directory not found. Make sure the website has been built."
    fi

    log "Syncing website to S3..."
    aws s3 sync public "s3://${REPO_NAME}" --delete --cache-control "max-age=31536000,public,immutable" --exclude "*.html" || error "Failed to sync website to S3"
    aws s3 sync public "s3://${REPO_NAME}" --delete --cache-control "no-cache" --include "*.html" || error "Failed to sync HTML files to S3"

    # Invalidate CloudFront cache
    log "Invalidating CloudFront cache..."
    DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Aliases.Items[?contains(@,'${DOMAIN_NAME}')]].Id" --output text)
    
    if [ -z "$DISTRIBUTION_ID" ]; then
        error "CloudFront distribution not found for ${DOMAIN_NAME}"
    fi

    INVALIDATION_ID=$(aws cloudfront create-invalidation --distribution-id ${DISTRIBUTION_ID} --paths "/*" --query 'Invalidation.Id' --output text)
    
    if [ -z "$INVALIDATION_ID" ]; then
        error "Failed to create CloudFront invalidation"
    fi

    log "CloudFront invalidation created. Invalidation ID: ${INVALIDATION_ID}"

    # Wait for invalidation to complete
    log "Waiting for CloudFront invalidation to complete..."
    aws cloudfront wait invalidation-completed --distribution-id ${DISTRIBUTION_ID} --id ${INVALIDATION_ID}

    if [ $? -ne 0 ]; then
        warn "CloudFront invalidation did not complete in the expected time. It may still be in progress."
    else
        log "CloudFront invalidation completed successfully."
    fi

    log "Website deployed successfully!"
}

deploy_website