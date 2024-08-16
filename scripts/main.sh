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

# Function to add name greeting
add_name_greeting() {
    local name="$1"
    local greeting="Hi ${name}!"
    sed -i "s|<h1 class=\"text-4xl font-bold\">.*</h1>|<h1 class=\"text-4xl font-bold\">${greeting}</h1>|" next-app/src/app/page.tsx
    log "Added greeting for ${name}"
}

# Function to remove name greeting
remove_name_greeting() {
    local site_name=$(grep '^siteName=' .config | cut -d'=' -f2)
    sed -i "s|<h1 class=\"text-4xl font-bold\">.*</h1>|<h1 class=\"text-4xl font-bold\">${site_name}</h1>|" next-app/src/app/page.tsx
    log "Removed custom greeting"
}

# Main execution
main() {
    get_domain_name

    # Check for name modifier
    if [[ "$1" == "name="* ]]; then
        NAME="${1#name=}"
    else
        NAME=""
    fi

    # Source and execute the individual modules
    for module in install_requirements setup_aws setup_terraform setup_site customize_site; do
        if [ ! -f "./scripts/${module}.sh" ]; then
            error "Required script not found: ./scripts/${module}.sh"
        fi
        log "Executing $module module..."
        if ! bash "./scripts/${module}.sh"; then
            error "Failed to execute $module module"
        fi
    done

    # Add or remove name greeting
    if [ -n "$NAME" ]; then
        add_name_greeting "$NAME"
    else
        remove_name_greeting
    fi

    # Deploy website
    if [ ! -f "./scripts/deploy_website.sh" ]; then
        error "Required script not found: ./scripts/deploy_website.sh"
    fi
    log "Deploying website..."
    if ! bash "./scripts/deploy_website.sh"; then
        error "Failed to deploy website"
    fi

    log "Website creation, customization, and deployment completed successfully!"
}

# Run the main function with all script arguments
main "$@"