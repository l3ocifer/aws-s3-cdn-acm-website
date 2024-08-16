#!/usr/bin/env bash

set -euo pipefail

deploy_website() {
    DOMAIN_NAME=$(cat .domain)
    REPO_NAME=$(echo "$DOMAIN_NAME" | sed -E 's/\.[^.]+$//')
    aws s3 sync next-app/out "s3://${REPO_NAME}" --delete --cache-control "max-age=31536000,public,immutable" --exclude "*.html" || { echo "Failed to sync website to S3" >&2; exit 1; }
    aws s3 sync next-app/out "s3://${REPO_NAME}" --delete --cache-control "no-cache" --include "*.html" || { echo "Failed to sync HTML files to S3" >&2; exit 1; }

    local distribution_id=$(cd terraform && terraform output -raw cloudfront_distribution_id)
    aws cloudfront create-invalidation --distribution-id "${distribution_id}" --paths "/*" || echo "Warning: Failed to invalidate CloudFront cache" >&2
}

deploy_website