#!/usr/bin/env bash

set -euo pipefail

deploy_website() {
    DOMAIN_NAME=$(cat .domain)
    REPO_NAME=$(echo "$DOMAIN_NAME" | sed -E 's/\.[^.]+$//')
    aws s3 sync next-app/out "s3://${REPO_NAME}" --delete --cache-control "max-age=31536000,public,immutable" --exclude "*.html" || { echo "Failed to sync website to S3" >&2; exit 1; }
    aws s3 sync next-app/out "s3://${REPO_NAME}" --delete --cache-control "no-cache" --include "*.html" || { echo "Failed to sync HTML files to S3" >&2; exit 1; }

    invalidate_cloudfront
}

invalidate_cloudfront() {
    CLOUDFRONT_ID=$(terraform -chdir=terraform output -raw cloudfront_distribution_id)
    if [ -n "$CLOUDFRONT_ID" ]; then
        echo "Invalidating CloudFront distribution: $CLOUDFRONT_ID"
        aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_ID" --paths "/*"
    else
        echo "No CloudFront distribution ID found. Skipping invalidation."
    fi
}

deploy_website