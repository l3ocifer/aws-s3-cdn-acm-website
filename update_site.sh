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
    npm run build
    cd ..
    log "Next.js app built successfully."
}

# Get Terraform outputs
get_terraform_outputs() {
    log "Retrieving Terraform outputs..."
    cd terraform
    if [ ! -f terraform.tfstate ]; then
        log "Error: terraform.tfstate not found. Please ensure Terraform has been initialized and applied."
        exit 1
    fi
    S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name)
    CLOUDFRONT_DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
    cd ..
    
    if [ -z "$S3_BUCKET_NAME" ] || [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        log "Error: Failed to retrieve required Terraform outputs"
        exit 1
    fi
    
    log "Retrieved S3 bucket name: $S3_BUCKET_NAME"
    log "Retrieved CloudFront distribution ID: $CLOUDFRONT_DISTRIBUTION_ID"
}

# Calculate site hash
get_site_hash() {
    local dir="next-app/out"
    if [ ! -d "$dir" ]; then
        return 1
    fi
    find "$dir" -type f -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1
}

# Sync S3 bucket
sync_s3_bucket() {
    log "Syncing files to S3 bucket '$S3_BUCKET_NAME'..."
    aws s3 sync next-app/out "s3://$S3_BUCKET_NAME" --delete --cache-control "no-store,max-age=0" --profile "${AWS_PROFILE:-default}"
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
    local hash_file=".site-hash"
    local new_hash=$1
    
    log "Updating git repository..."
    
    # Add all Next.js app changes
    git add next-app/
    
    # Only commit if there are changes
    if ! git diff --cached --quiet; then
        git commit -m "update next.js app files"
        git push
        log "Next.js app changes committed and pushed."
    else
        log "No changes to Next.js app files."
    fi
    
    echo "$new_hash" > "$hash_file"
    
    if git diff --quiet "$hash_file"; then
        log "No changes to site hash."
        return 0
    fi
    
    git add "$hash_file"
    git commit -m "update site hash after rebuild"
    git push
    log "Git repository updated successfully."
}

# Main function
update_site() {
    log "Starting website update process..."
    setup_node
    build_next_app
    
    # Get new site hash
    new_hash=$(get_site_hash)
    if [ ! -f ".site-hash" ] || [ "$(cat .site-hash)" != "$new_hash" ]; then
        log "Changes detected. Deploying updates..."
        get_terraform_outputs
        sync_s3_bucket
        invalidate_cloudfront
        update_git "$new_hash"
        log "Website updated successfully!"
    else
        log "No changes detected. Skipping deployment."
    fi
}

# Run the script
update_site