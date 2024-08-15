#!/usr/bin/env bash

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

# Source helper functions
source scripts/env_checks.sh
source scripts/git_operations.sh
source scripts/domain_management.sh
source scripts/aws_operations.sh

# Function to get domain name
get_domain_name() {
    if [ ! -f .domain ]; then
        error "Domain file (.domain) not found. Please run createwebsite.sh first."
    fi
    DOMAIN_NAME=$(cat .domain)
    export DOMAIN_NAME
}

# Check for destroy flag
DESTROY=false
if [ "${1:-}" = "td" ]; then
    DESTROY=true
fi

get_domain_name

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f terraform/.terraform/terraform.tfstate*
}

# Set trap for cleanup
trap cleanup EXIT

# Source and execute the individual modules
for module in install_requirements setup_aws setup_terraform setup_site deploy_website; do
    if [ ! -f "./scripts/${module}.sh" ]; then
        error "Required script not found: ./scripts/${module}.sh"
    fi
    log "Executing $module module..."
    if ! source "./scripts/${module}.sh"; then
        error "Failed to execute $module module"
    fi
done

if [ "$DESTROY" = true ]; then
    log "Destroying infrastructure for ${DOMAIN_NAME}..."
    if ! (cd terraform && terraform destroy -auto-approve -var-file=terraform.tfvars); then
        error "Failed to destroy infrastructure"
    fi

    # Destroy the backend S3 bucket
    bucket_name="${DOMAIN_NAME}-tf-state"
    log "Removing backend S3 bucket: $bucket_name"
    if ! aws s3 rm "s3://$bucket_name" --recursive; then
        warn "Failed to remove contents of S3 bucket: $bucket_name"
    fi
    if ! aws s3api delete-bucket --bucket "$bucket_name"; then
        warn "Failed to delete S3 bucket: $bucket_name"
    fi

    log "Infrastructure and backend destroyed successfully."
else
    log "Deployment complete! Your website should be accessible at https://${DOMAIN_NAME}"
    log "Please allow some time for the DNS changes to propagate."
    (cd terraform && terraform output name_servers)

    log "Project setup complete."
fi
