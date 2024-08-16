#!/bin/bash
set -euo pipefail

# Function to get domain name
get_domain_name() {
    if [ ! -f .domain ]; then
        echo "ERROR: Domain file (.domain) not found. Please run createwebsite.sh first." >&2
        exit 1
    fi
    DOMAIN_NAME=$(cat .domain)
    REPO_NAME=$(echo "$DOMAIN_NAME" | sed -E 's/\.[^.]+$//')
    export DOMAIN_NAME
    export REPO_NAME
}

# Call the function to set DOMAIN_NAME and REPO_NAME
get_domain_name

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f terraform/.terraform/terraform.tfstate*
}

# Set trap for cleanup
trap cleanup EXIT

# Function to setup AWS resources
setup_aws() {
    echo "Setting up AWS resources..."
    source ./scripts/setup_aws.sh
    create_or_get_hosted_zone
}

# Function to add name greeting
add_name_greeting() {
    local name="$1"
    local greeting="Hi ${name}!"
    local file="next-app/src/app/page.tsx"
    
    if [ -f "$file" ]; then
        sed -i "s|<h1 class=\"text-4xl font-bold\">.*</h1>|<h1 class=\"text-4xl font-bold\">${greeting}</h1>|" "$file"
        echo "Added greeting for ${name}"
    else
        echo "WARNING: $file not found. Cannot add greeting." >&2
    fi
}

# Function to remove name greeting
remove_name_greeting() {
    local file="next-app/src/app/page.tsx"
    
    if [ -f "$file" ]; then
        sed -i "s|<h1 class=\"text-4xl font-bold\">.*</h1>|<h1 class=\"text-4xl font-bold\">Welcome to ${DOMAIN_NAME}</h1>|" "$file"
        echo "Removed custom greeting"
    else
        echo "WARNING: $file not found. Cannot remove greeting." >&2
    fi
}

# Main execution
main() {
    # Check for name modifier
    if [ $# -gt 0 ] && [[ "$1" == "name="* ]]; then
        NAME="${1#name=}"
    else
        NAME=""
    fi

    # Source and execute the individual modules
    for module in install_requirements setup_aws setup_terraform setup_site; do
        if [ ! -f "./scripts/${module}.sh" ]; then
            echo "ERROR: Required script not found: ./scripts/${module}.sh" >&2
            exit 1
        fi
        echo "Executing $module module..."
        if ! bash "./scripts/${module}.sh"; then
            echo "ERROR: Failed to execute $module module" >&2
            exit 1
        fi
    done

    # Add or remove name greeting
    if [ -n "$NAME" ]; then
        add_name_greeting "$NAME"
    else
        remove_name_greeting
    fi

    # Build the Next.js app
    echo "Building Next.js app..."
    cd next-app
    npm run build
    cd ..

    # Deploy website
    if [ ! -f "./scripts/deploy_website.sh" ]; then
        echo "ERROR: Required script not found: ./scripts/deploy_website.sh" >&2
        exit 1
    fi
    echo "Deploying website..."
    if ! bash "./scripts/deploy_website.sh"; then
        echo "ERROR: Failed to deploy website" >&2
        exit 1
    fi

    echo "Website creation, customization, and deployment completed successfully!"
}

# Run the main function with all script arguments
main "$@"