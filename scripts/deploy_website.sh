#!/usr/bin/env bash

set -euo pipefail

# Function to deploy website
deploy_website() {
    aws s3 sync react/build "s3://${DOMAIN_NAME}" --delete || error "Failed to sync website to S3"

    local distribution_id=$(cd terraform && terraform output -raw cloudfront_distribution_id)
    aws cloudfront create-invalidation --distribution-id "${distribution_id}" --paths "/*" || warn "Failed to invalidate CloudFront cache"
}

deploy_website
