#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }

# Function to get domain name
get_domain_name() {
    if [ ! -f .domain ]; then
        error "Domain file (.domain) not found. Please run createwebsite.sh first."
    fi
    DOMAIN_NAME=$(cat .domain)
    REPO_NAME=$(echo "$DOMAIN_NAME" | sed -E 's/\.[^.]+$//')
    export DOMAIN_NAME
    export REPO_NAME
}

get_domain_name

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f terraform/.terraform/terraform.tfstate*
}

# Set trap for cleanup
trap cleanup EXIT

# Source and execute the individual modules
main() {
    get_domain_name
    setup_aws
    setup_terraform
    setup_site
    deploy_website
}

main

log "Deployment complete! Your website should be accessible at https://${DOMAIN_NAME}"
log "Please allow some time for the DNS changes to propagate."
(cd terraform && terraform output name_servers)

log "Project setup complete."