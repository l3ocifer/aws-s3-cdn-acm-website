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

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f terraform/.terraform/terraform.tfstate*
}

# Set trap for cleanup
trap cleanup EXIT

# Function to setup AWS resources
setup_aws() {
    log "Setting up AWS resources..."
    source ./scripts/setup_aws.sh
    create_or_get_hosted_zone
}

# Main execution
main() {
    get_domain_name

    # Source and execute the individual modules
    for module in install_requirements setup_aws setup_terraform setup_site deploy_website customize_site; do
        if [ ! -f "./scripts/${module}.sh" ]; then
            error "Required script not found: ./scripts/${module}.sh"
        fi
        log "Executing $module module..."
        if ! bash "./scripts/${module}.sh"; then
            error "Failed to execute $module module"
        fi
    done

    log "Website creation, deployment, and customization completed successfully!"
}

# Run the main function
main