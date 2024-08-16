#!/usr/bin/env bash

set -euo pipefail

deploy_website() {
    DOMAIN_NAME=$(cat .domain)
    REPO_NAME=$(echo "$DOMAIN_NAME" | sed -E 's/\.[^.]+$//')
    
    # Check if the public directory exists
    if [ ! -d "public" ]; then
        echo "Error: 'public' directory not found. Make sure the website has been built." >&2
        exit 1
    fi

    aws s3 sync public "s3://${REPO_NAME}" --delete --cache-control "max-age=31536000,public,immutable" --exclude "*.html" || { echo "Failed to sync website to S3" >&2; exit 1; }
    aws s3 sync public "s3://${REPO_NAME}" --delete --cache-control "no-cache" --include "*.html" || { echo "Failed to sync HTML files to S3" >&2; exit 1; }

    # Invalidate CloudFront cache
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
    aws cloudfront wait invalidation-completed --distribution-id ${DISTRIBUTION_ID} --id ${INVALIDATION_ID}

    if [ $? -ne 0 ]; then
        warn "CloudFront invalidation did not complete in the expected time. It may still be in progress."
    else
        log "CloudFront invalidation completed successfully."
    fi

    log "Website deployed successfully!"
}

deploy_website