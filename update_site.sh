#!/bin/bash

set -e

# Set up logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Set up Node.js version
setup_node() {
    log "Setting up Node.js version..."
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 18.18.0 > /dev/null 2>&1
    nvm alias default 18.18.0 > /dev/null 2>&1
    nvm use default > /dev/null 2>&1
    export PATH="$NVM_DIR/versions/node/v18.18.0/bin:$PATH"
    hash -r
    node_version=$(node --version)
    if [[ "$node_version" != "v18.18.0" ]]; then
        log "Error: Node.js version mismatch. Got $node_version, expected v18.18.0"
        exit 1
    fi
    log "Using Node.js version: $node_version"
}

# Build the Next.js app
build_next_app() {
    log "Building Next.js app..."
    cd next-app
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
    
    # Sync all files with appropriate cache headers
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --delete \
        --cache-control "public, max-age=0, must-revalidate" \
        --content-type "text/html; charset=utf-8" \
        --exclude "*" \
        --include "*.html"

    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --cache-control "public, max-age=31536000, immutable" \
        --exclude "*" \
        --include "_next/*"

    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --cache-control "public, max-age=31536000, immutable" \
        --exclude "*" \
        --include "*.js" \
        --include "*.css" \
        --include "*.json" \
        --include "*.ico" \
        --include "*.png" \
        --include "*.jpg" \
        --include "*.jpeg" \
        --include "*.svg" \
        --include "*.webp" \
        --include "*.woff" \
        --include "*.woff2" \
        --include "*.ttf"
        
    log "Files synced to S3 bucket '$S3_BUCKET_NAME'."
}

# Invalidate CloudFront distribution
invalidate_cloudfront() {
    log "Creating invalidation for CloudFront distribution '$CLOUDFRONT_DISTRIBUTION_ID'..."
    INVALIDATION_ID=$(aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*" --query 'Invalidation.Id' --output text)
    log "Invalidation '$INVALIDATION_ID' created."
}

# Main function
update_site() {
    log "Starting website update process..."
    setup_node
    build_next_app
    get_terraform_outputs
    sync_s3_bucket
    invalidate_cloudfront
    log "Website updated successfully!"
}

# Run the script
update_site