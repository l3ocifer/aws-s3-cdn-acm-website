#!/bin/bash

set -euo pipefail

export NEXT_TELEMETRY_DISABLED=1

# Disable the AWS CLI pager
export AWS_PAGER=""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
for cmd in git curl; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is not installed. Please install it and try again." >&2
        exit 1
    fi
done

# Check if environment variables are set
if [ -z "${GITHUB_USERNAME:-}" ] || [ -z "${GITHUB_ACCESS_TOKEN:-}" ]; then
    echo "Error: GITHUB_USERNAME and GITHUB_ACCESS_TOKEN must be set in your environment." >&2
    exit 1
fi

# Function to get or prompt for domain name
get_domain_name() {
    if [ -n "${LAST_WEBSITE_REPO:-}" ]; then
        read -p "Use the last repo ($LAST_WEBSITE_REPO)? (y/n): " use_last
        if [[ $use_last =~ ^[Yy]$ ]]; then
            DOMAIN_NAME=$LAST_WEBSITE_REPO
        else
            read -e -p "Enter the domain name for your website (e.g., example.com): " DOMAIN_NAME
        fi
    else
        read -e -p "Enter the domain name for your website (e.g., example.com): " DOMAIN_NAME
    fi
    echo "$DOMAIN_NAME" > .domain
    REPO_NAME=${DOMAIN_NAME%%.*}
    export DOMAIN_NAME REPO_NAME LAST_WEBSITE_REPO=$DOMAIN_NAME
}

# Function to update repo with latest template changes
update_repo_from_template() {
    local template_repo="website"
    local temp_dir=$(mktemp -d)

    echo "Updating from template repository..."
    git clone "https://github.com/$GITHUB_USERNAME/$template_repo.git" "$temp_dir"

    # Copy files from template, excluding .git, .domain, .content, and .logo
    rsync -av --exclude='.git' --exclude='.domain' --exclude='.content' --exclude='.logo' "$temp_dir/" .

    # Update specific files with customized content
    if [ -f terraform/backend.tf ]; then
        sed -i'' -e "s/DOMAIN_NAME_PLACEHOLDER/$DOMAIN_NAME/g" terraform/backend.tf
    else
        echo "Warning: terraform/backend.tf not found. Skipping customization."
    fi

    if [ -f scripts/setup_terraform.sh ]; then
        sed -i'' -e "s/DOMAIN_NAME_PLACEHOLDER/$DOMAIN_NAME/g" scripts/setup_terraform.sh
    else
        echo "Warning: scripts/setup_terraform.sh not found. Skipping customization."
    fi

    rm -rf "$temp_dir"
}

# Function to setup the website repo
setup_website_repo() {
    local use_td=false
    local template_repo="website"

    # Check if 'td' argument is provided
    if [ "${1:-}" = "td" ]; then
        use_td=true
    fi

    # Prompt the user to choose an existing subdirectory or create a new one
    echo "Choose an existing subdirectory or create a new one:"
    select dir in ~/git/*/ "Create new directory"; do
        if [ "$dir" = "Create new directory" ]; then
            read -e -p "Enter a new subdirectory name: " subdir_name
            mkdir -p ~/git/$subdir_name
            cd ~/git/$subdir_name
            break
        elif [ -d "$dir" ]; then
            cd "$dir"
            break
        else
            echo "Invalid selection" >&2
            exit 1
        fi
    done

    get_domain_name

    if [ -d "$REPO_NAME" ]; then
        echo "Directory $REPO_NAME already exists locally. Checking GitHub..."
        if curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME" | grep -q "200"; then
            echo "Repository exists on GitHub. Updating..."
            cd "$REPO_NAME"
            git fetch origin
            git reset --hard origin/master
            update_repo_from_template
        else
            echo "Repository doesn't exist on GitHub. Cleaning directory and setting up as new..."
            cd "$REPO_NAME"
            rm -rf * .[!.]* ..?*
            git init
            update_repo_from_template
        fi
    else
        echo "Creating new repository $REPO_NAME..."
        mkdir "$REPO_NAME"
        cd "$REPO_NAME"
        git init
        update_repo_from_template
    fi

    # Ensure remote is set correctly
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

    # Ensure .domain file exists and is up to date
    echo "$DOMAIN_NAME" > .domain

    # Check for .content file
    if [ ! -f .content ]; then
        echo "No .content file found. Creating a default one."
        echo "Welcome to $DOMAIN_NAME" > .content
    fi

    # Check for .logo file
    if [ ! -f .logo ]; then
        echo "No .logo file found. Using default logo."
        echo "default" > .logo
    fi

    # Commit any changes
    git add .
    git commit -m "Initial setup for $DOMAIN_NAME" || true  # Commit only if there are changes

    # Create repository on GitHub if it doesn't exist
    if ! curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME" | grep -q "200"; then
        echo "Creating new repository on GitHub..."
        curl -H "Authorization: token $GITHUB_ACCESS_TOKEN" https://api.github.com/user/repos -d '{"name":"'$REPO_NAME'", "private":true}'
    fi

    # Push changes
    if ! git push -u origin master --force; then
        echo "Error: Failed to push changes to GitHub." >&2
        echo "Current directory: $(pwd)" >&2
        echo "Git status:" >&2
        git status >&2
        echo "Git remote -v:" >&2
        git remote -v >&2
        exit 1
    fi

    echo "Website repo setup complete. Your repo is at https://github.com/$GITHUB_USERNAME/$REPO_NAME"

    # Ensure scripts are executable
    chmod +x scripts/*.sh

    # Run main.sh
    if [ -f "scripts/main.sh" ]; then
        if [ "$use_td" = true ]; then
            if ! ./scripts/main.sh td; then
                echo "Error: Failed to execute scripts/main.sh td" >&2
                exit 1
            fi
        else
            if ! ./scripts/main.sh; then
                echo "Error: Failed to execute scripts/main.sh" >&2
                exit 1
            fi
        fi
    else
        echo "Error: main.sh not found in the scripts directory." >&2
        exit 1
    fi
}
# Run the function with command line argument
setup_website_repo "${1:-}"
