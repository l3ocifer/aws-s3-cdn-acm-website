#!/bin/bash

set -euo pipefail

# Disable the AWS CLI pager
export AWS_PAGER=""

# Disable Next.js telemetry
export NEXT_TELEMETRY_DISABLED=1

# Check for required commands
for cmd in git curl aws; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed. Please install it and try again." >&2
        exit 1
    fi
done

# Check if environment variables are set
if [ -z "${GITHUB_USERNAME:-}" ] || [ -z "${GITHUB_ACCESS_TOKEN:-}" ]; then
    echo "Error: GITHUB_USERNAME and GITHUB_ACCESS_TOKEN must be set in your environment." >&2
    exit 1
fi

LAST_DOMAIN_FILE="/tmp/last_website_domain_$$.tmp"

# Function to get or prompt for domain name and repo path
get_domain_and_repo() {
    if [ -f "$LAST_DOMAIN_FILE" ]; then
        LAST_DOMAIN=$(cat "$LAST_DOMAIN_FILE")
        read -p "Use the last domain ($LAST_DOMAIN)? (y/n): " use_last
        if [[ $use_last =~ ^[Yy]$ ]]; then
            DOMAIN_NAME=$LAST_DOMAIN
        else
            read -e -p "Enter the domain name for your website (e.g., example.com): " DOMAIN_NAME
        fi
    else
        read -e -p "Enter the domain name for your website (e.g., example.com): " DOMAIN_NAME
    fi
    echo "$DOMAIN_NAME" > "$LAST_DOMAIN_FILE"
    REPO_NAME=${DOMAIN_NAME%%.*}

    read -e -p "Enter the path for the git repository (default: $HOME/git/$REPO_NAME): " REPO_PATH
    REPO_PATH=${REPO_PATH:-"$HOME/git/$REPO_NAME"}

    export DOMAIN_NAME REPO_NAME REPO_PATH
}

# Function to setup or update the website repository
setup_or_update_repo() {
    if [ -d "$REPO_PATH" ]; then
        echo "Repository already exists. Updating..."
        cd "$REPO_PATH"
        git fetch origin
        git reset --hard origin/master
    else
        echo "Cloning website template repository..."
        mkdir -p "$REPO_PATH"
        git clone "https://github.com/$GITHUB_USERNAME/website.git" "$REPO_PATH"
        cd "$REPO_PATH"
    fi

    # Make scripts executable
    chmod +x scripts/*.sh

    # Check if the GitHub repository exists
    if ! curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME" | grep -q "200"; then
        echo "Attempting to create new repository on GitHub..."
        create_response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GITHUB_ACCESS_TOKEN" https://api.github.com/user/repos -d '{"name":"'$REPO_NAME'", "private":true}')
        status_code=$(echo "$create_response" | tail -n1)
        response_body=$(echo "$create_response" | sed '$d')

        if [ "$status_code" != "201" ]; then
            echo "Failed to create GitHub repository. Status code: $status_code"
            echo "Response: $response_body"
            echo "The repository may already exist. Continuing with the assumption that it does."
        else
            echo "GitHub repository created successfully."
        fi
    else
        echo "GitHub repository $REPO_NAME already exists."
    fi

    # Set the new origin
    git remote set-url origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

    # Update domain-specific files
    echo "$DOMAIN_NAME" > .domain
    sed -i.bak "s/DOMAIN_NAME_PLACEHOLDER/$DOMAIN_NAME/g" terraform/backend.tf
    rm -f terraform/backend.tf.bak

    # Commit changes
    git add .
    git commit -m "Update setup for $DOMAIN_NAME" || true

    # Push changes
    echo "Pushing changes to GitHub..."
    if ! git push -u origin master; then
        echo "Failed to push to GitHub. You may need to push manually."
        echo "Try running: git push -u origin master"
        echo "If you encounter issues, ensure your GitHub access token has the correct permissions."
    else
        echo "Changes pushed to GitHub successfully."
    fi
}

# Main execution
get_domain_and_repo
setup_or_update_repo

# Run the main setup script
if [ -f "scripts/main.sh" ]; then
    if [ "${1:-}" = "td" ]; then
        ./scripts/main.sh td
    else
        ./scripts/main.sh
    fi
else
    echo "Error: main.sh not found in the scripts directory." >&2
    exit 1
fi

# Cleanup
rm -f "$LAST_DOMAIN_FILE"

echo "Website setup complete. Your repository is at https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo "Your website should be accessible at https://$DOMAIN_NAME once DNS propagation is complete."
