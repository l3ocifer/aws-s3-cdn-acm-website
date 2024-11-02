#!/bin/bash

set -e

# Set up logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Build the Next.js app
build_next_app() {
    log "Building Next.js app..."
    cd next-app
    rm -rf .next
    rm -rf out
    npm install
    NEXT_PUBLIC_BASE_PATH="" npm run build
    cd ..
    log "Next.js app built successfully."
}

# Get Terraform outputs
get_terraform_outputs() {
    log "Retrieving Terraform outputs..."
    cd terraform
    S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name)
    CLOUDFRONT_DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
    cd ..
    log "Retrieved S3 bucket name: $S3_BUCKET_NAME"
    log "Retrieved CloudFront distribution ID: $CLOUDFRONT_DISTRIBUTION_ID"
}

# Sync S3 bucket
sync_s3_bucket() {
    log "Syncing files to S3 bucket '$S3_BUCKET_NAME'..."
    
    # HTML files
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --delete \
        --size-only \
        --metadata-directive REPLACE \
        --cache-control "public, max-age=0, must-revalidate" \
        --exclude "_next/*" \
        --exclude "*.js" \
        --exclude "*.css" \
        --exclude "*.json" \
        --exclude "*.xml" \
        --exclude "*.txt" \
        --exclude "*.ico" \
        --exclude "*.jpg" \
        --exclude "*.jpeg" \
        --exclude "*.png" \
        --exclude "*.gif" \
        --exclude "*.svg" \
        --exclude "*.woff" \
        --exclude "*.woff2" \
        --exclude "*.ttf" \
        --content-type "text/html; charset=utf-8"

    # Next.js static files
    aws s3 sync next-app/out/_next "s3://$S3_BUCKET_NAME/_next" \
        --size-only \
        --metadata-directive REPLACE \
        --cache-control "public, max-age=31536000, immutable"

    # JavaScript files
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --size-only \
        --metadata-directive REPLACE \
        --cache-control "public, max-age=31536000, immutable" \
        --exclude "*" \
        --include "*.js" \
        --content-type "application/javascript"

    # CSS files
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --size-only \
        --metadata-directive REPLACE \
        --cache-control "public, max-age=31536000, immutable" \
        --exclude "*" \
        --include "*.css" \
        --content-type "text/css"

    # Images and other static assets
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --size-only \
        --metadata-directive REPLACE \
        --cache-control "public, max-age=31536000, immutable" \
        --exclude "*" \
        --include "*.ico" --content-type "image/x-icon" \
        --include "*.jpg" --content-type "image/jpeg" \
        --include "*.jpeg" --content-type "image/jpeg" \
        --include "*.png" --content-type "image/png" \
        --include "*.gif" --content-type "image/gif" \
        --include "*.svg" --content-type "image/svg+xml" \
        --include "*.woff" --content-type "font/woff" \
        --include "*.woff2" --content-type "font/woff2" \
        --include "*.ttf" --content-type "font/ttf"

    log "Files synced to S3 bucket '$S3_BUCKET_NAME'."
}

# Invalidate CloudFront distribution
invalidate_cloudfront() {
    log "Creating invalidation for CloudFront distribution '$CLOUDFRONT_DISTRIBUTION_ID'..."
    INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)
    log "Invalidation created with ID: $INVALIDATION_ID"
    
    # Wait for invalidation to complete
    aws cloudfront wait invalidation-completed \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --id "$INVALIDATION_ID"
    log "Invalidation completed successfully."
}

# Main function
main() {
    log "Starting website update process..."
    build_next_app
    get_terraform_outputs
    sync_s3_bucket
    invalidate_cloudfront
    log "Website update completed successfully!"
}

# Run the script
main
