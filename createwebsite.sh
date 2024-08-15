#!/bin/bash

set -euo pipefail

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
    if [ -f .domain ]; then
        DOMAIN_NAME=$(cat .domain)
    else
        read -e -p "Enter the domain name for your website (e.g., example.com): " DOMAIN_NAME
        echo "$DOMAIN_NAME" > .domain
    fi
    REPO_NAME=${DOMAIN_NAME%%.*}
    export DOMAIN_NAME REPO_NAME
}

# Function to setup the website repo
setup_website_repo() {
    local template_repo="website"
    local use_td=false

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
        echo "Repository $REPO_NAME already exists locally. Updating..."
        cd "$REPO_NAME"
        git fetch origin
        git reset --hard origin/master
    else
        echo "Cloning repository $REPO_NAME..."
        if ! git clone "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git" 2>/dev/null; then
            echo "Repository doesn't exist. Cloning template repository..."
            if ! git clone "https://github.com/$GITHUB_USERNAME/$template_repo.git" "$REPO_NAME"; then
                echo "Error: Failed to clone the template repository." >&2
                exit 1
            fi
        fi
        cd "$REPO_NAME"
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

    # Pull changes from remote
    git pull origin $current_branch --rebase

    # Push changes
    if ! git push -u origin "$current_branch"; then
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
