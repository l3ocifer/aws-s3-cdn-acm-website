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
    
    # Ensure the build directory exists and is clean
    rm -rf .next out
    mkdir -p .next
    
    # Install dependencies with exact versions
    log "Installing dependencies..."
    npm ci --prefer-offline --no-audit --progress=false
    
    # Run type checking and linting before build
    log "Running type check..."
    if ! npm run typecheck 2>/dev/null; then
        log "Warning: Type checking failed, but continuing with build..."
    fi
    
    # Build with production optimization (includes static export)
    log "Building production bundle..."
    if ! NODE_ENV=production npm run build; then
        log "Error: Next.js build failed"
        cd ..
        exit 1
    fi
    
    # Copy build output to out directory
    if [ -d ".next/standalone" ]; then
        cp -r .next/standalone/* out/
    elif [ -d ".next" ]; then
        mkdir -p out
        cp -r .next/* out/
    fi
    
    # Copy static assets
    if [ -d ".next/static" ]; then
        mkdir -p out/_next
        cp -r .next/static out/_next/
    fi
    
    # Copy public directory if it exists
    if [ -d "public" ]; then
        cp -r public/* out/
    fi
    
    # Verify build output
    if [ ! -d "out" ] || [ -z "$(ls -A out)" ]; then
        log "Error: Build output directory is empty or missing after copy"
        cd ..
        exit 1
    fi
    
    cd ..
    log "Next.js app built successfully."
}

# Get AWS resources
get_aws_resources() {
    log "Retrieving AWS resources..."
    
    # Get domain name from current directory name
    DOMAIN_NAME=$(basename $(pwd) | sed 's/_com$/.com/')
    
    # Get S3 bucket (specifically the website bucket)
    S3_BUCKET_NAME=$(aws s3 ls --profile "${AWS_PROFILE:-default}" | grep "$DOMAIN_NAME" | grep "website" | awk '{print $3}')
    
    # Get CloudFront distribution
    CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions --profile "${AWS_PROFILE:-default}" --query "DistributionList.Items[?Aliases.Items[?contains(@,'${DOMAIN_NAME}')]].Id" --output text)
    
    if [ -z "$S3_BUCKET_NAME" ] || [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        log "Error: Failed to retrieve required AWS resources"
        log "S3 Bucket: $S3_BUCKET_NAME"
        log "CloudFront Distribution: $CLOUDFRONT_DISTRIBUTION_ID"
        exit 1
    fi
    
    log "Retrieved S3 bucket name: $S3_BUCKET_NAME"
    log "Retrieved CloudFront distribution ID: $CLOUDFRONT_DISTRIBUTION_ID"
}

# Sync S3 bucket with proper content types
sync_s3_bucket() {
    log "Syncing files to S3 bucket '$S3_BUCKET_NAME'..."
    if [ ! -d "next-app/out" ]; then
        log "Error: Build output directory not found. Running build first..."
        build_next_app
    fi
    
    if [ ! -d "next-app/out" ]; then
        log "Error: Build output directory still missing after build"
        exit 1
    fi
    
    # First sync: Static assets with long cache
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --delete \
        --cache-control "public, max-age=31536000, immutable" \
        --include "_next/*" \
        --include "*.js" \
        --include "*.css" \
        --include "*.woff2" \
        --include "*.jpg" \
        --include "*.png" \
        --include "*.svg" \
        --include "*.ico" \
        --content-type "application/javascript:*.js" \
        --content-type "text/css:*.css" \
        --content-type "font/woff2:*.woff2" \
        --content-type "image/jpeg:*.jpg" \
        --content-type "image/png:*.png" \
        --content-type "image/svg+xml:*.svg" \
        --content-type "image/x-icon:*.ico" \
        --profile "${AWS_PROFILE:-default}"
    
    # Second sync: HTML files with no-cache
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --delete \
        --cache-control "no-cache, no-store, must-revalidate" \
        --exclude "*" \
        --include "*.html" \
        --content-type "text/html" \
        --profile "${AWS_PROFILE:-default}"
    
    # Third sync: Root files and directories
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" \
        --delete \
        --cache-control "no-cache, no-store, must-revalidate" \
        --exclude "_next/*" \
        --exclude "*.html" \
        --exclude "*.js" \
        --exclude "*.css" \
        --exclude "*.woff2" \
        --exclude "*.jpg" \
        --exclude "*.png" \
        --exclude "*.svg" \
        --exclude "*.ico" \
        --profile "${AWS_PROFILE:-default}"
    
    log "Files synced to S3 bucket '$S3_BUCKET_NAME'."
}

# Invalidate CloudFront distribution
invalidate_cloudfront() {
    log "Creating invalidation for CloudFront distribution '$CLOUDFRONT_DISTRIBUTION_ID'..."
    INVALIDATION_ID=$(aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*" --query 'Invalidation.Id' --output text --profile "${AWS_PROFILE:-default}")
    log "Invalidation '$INVALIDATION_ID' created."
}

# Update git repository
update_git() {
    log "Updating git repository..."
    git add next-app/
    git commit -m "update next.js app files" || true
    git push || true
    log "Git repository updated."
}

# Main function
update_site() {
    log "Starting website update process..."
    setup_node
    build_next_app
    get_aws_resources
    sync_s3_bucket
    invalidate_cloudfront
    update_git
    log "Website updated successfully!"
}

# Run the script
update_site