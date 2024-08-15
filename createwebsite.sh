#!/bin/bash

set -euo pipefail

# Disable the AWS CLI pager
export AWS_PAGER=""

# Disable Next.js telemetry
export NEXT_TELEMETRY_DISABLED=1

# File to store the last used domain
LAST_DOMAIN_FILE="$HOME/.last_website_domain"

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
    export DOMAIN_NAME REPO_NAME
}

# Function to update repo with latest template changes
update_repo_from_template() {
    local template_repo="website"
    local template_remote="template"

    echo "Updating from template repository..."

    # Add template repository as a remote if it doesn't exist
    if ! git remote | grep -q "^${template_remote}$"; then
        git remote add ${template_remote} "https://github.com/$GITHUB_USERNAME/$template_repo.git"
    fi

    # Fetch the latest changes from the template repository
    git fetch ${template_remote}

    # Create a temporary branch to merge changes
    git checkout -b temp_update_branch

    # Merge changes from the template repository, excluding certain files
    git merge -X theirs --no-commit --no-ff ${template_remote}/main

    # Remove files that should not be updated
    git reset HEAD .domain .content .logo
    git checkout -- .domain .content .logo

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

    # Commit the changes
    git commit -m "Update from template repository"

    # Switch back to the main branch and merge the changes
    git checkout master
    git merge --no-ff temp_update_branch -m "Merge template updates"

    # Delete the temporary branch
    git branch -d temp_update_branch

    # Remove the template remote
    git remote remove ${template_remote}
}

# Function to setup the website repo
setup_website_repo() {
    local use_td=false

    # Check if 'td' argument is provided
    if [ "${1:-}" = "td" ]; then
        use_td=true
    fi

    get_domain_name

    # Check if we're already in the correct directory
    if [ "$(basename "$PWD")" != "$REPO_NAME" ]; then
        # If not, navigate to the correct directory or create it
        if [ -d "$HOME/git/$REPO_NAME" ]; then
            cd "$HOME/git/$REPO_NAME"
        else
            mkdir -p "$HOME/git/$REPO_NAME"
            cd "$HOME/git/$REPO_NAME"
        fi
    fi

    if [ -d .git ]; then
        echo "Repository $REPO_NAME already exists locally. Updating..."
        git fetch origin
        git reset --hard origin/master
        update_repo_from_template
    else
        echo "Cloning repository $REPO_NAME..."
        if ! git clone "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git" . 2>/dev/null; then
            echo "Repository doesn't exist. Cloning template repository..."
            if ! git clone "https://github.com/$GITHUB_USERNAME/website.git" .; then
                echo "Error: Failed to clone the template repository." >&2
                exit 1
            fi
            update_repo_from_template
        fi
    fi

    # Ensure remote is set correctly
    git remote set-url origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

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
    git commit -m "Update setup for $DOMAIN_NAME" || true  # Commit only if there are changes

    # Get the current branch name
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "Current branch: $current_branch"

    # Create repository on GitHub if it doesn't exist
    if ! curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME" | grep -q "200"; then
        echo "Creating new repository on GitHub..."
        curl -H "Authorization: token $GITHUB_ACCESS_TOKEN" https://api.github.com/user/repos -d '{"name":"'$REPO_NAME'", "private":true}'
    fi

    # Push changes
    if ! git push -u origin "$current_branch" --force; then
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
