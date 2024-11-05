#!/bin/bash

set -euo pipefail

log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ${level}: ${message}"
}

get_terraform_outputs() {
    log "INFO" "Retrieving Terraform outputs..."
    cd terraform
    S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name)
    CLOUDFRONT_DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
    cd ..
    
    if [ -z "$S3_BUCKET_NAME" ] || [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        log "ERROR" "Failed to retrieve Terraform outputs"
        exit 1
    fi
    
    log "SUCCESS" "Retrieved Terraform outputs"
}

build_leptos() {
    log "INFO" "Starting Leptos build..."
    cd leptos-app
    
    log "INFO" "Cleaning previous build artifacts..."
    rm -rf target/site
    mkdir -p target/site/pkg
    
    log "INFO" "Building application..."
    if ! trunk build --release; then
        log "ERROR" "Build failed"
        exit 1
    fi
    
    log "INFO" "Copying build artifacts..."
    cp -r dist/* target/site/
    
    if [ ! -f "target/site/index.html" ]; then
        log "ERROR" "Build verification failed"
        ls -la target/site/
        exit 1
    fi
    
    cd ..
    log "SUCCESS" "Build completed"
}

sync_s3_bucket() {
    log "INFO" "Syncing with S3..."
    
    if ! aws s3 rm "s3://$S3_BUCKET_NAME" --recursive; then
        log "ERROR" "Failed to clean bucket"
        exit 1
    fi
    
    if ! aws s3 sync "leptos-app/target/site" "s3://$S3_BUCKET_NAME" \
        --delete \
        --cache-control "no-cache" \
        --content-type "text/html" \
        --exclude "*" \
        --include "index.html"; then
        log "ERROR" "Failed to sync index.html"
        exit 1
    fi
    
    if ! aws s3 sync "leptos-app/target/site" "s3://$S3_BUCKET_NAME" \
        --delete \
        --cache-control "public, max-age=31536000, immutable" \
        --exclude "*" \
        --include "*.js" \
        --include "*.wasm" \
        --include "*.css" \
        --include "pkg/*"; then
        log "ERROR" "Failed to sync assets"
        exit 1
    fi
    
    log "SUCCESS" "Sync completed"
}

invalidate_cloudfront() {
    log "INFO" "Invalidating CloudFront..."
    
    if ! aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text > /dev/null; then
        log "ERROR" "Invalidation failed"
        exit 1
    fi
    
    log "SUCCESS" "Invalidation created"
}

main() {
    log "INFO" "Starting deployment..."
    build_leptos
    get_terraform_outputs
    sync_s3_bucket
    invalidate_cloudfront
    log "SUCCESS" "🚀 Deployment completed!"
}

main