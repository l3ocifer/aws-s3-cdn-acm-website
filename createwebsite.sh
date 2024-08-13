#!/bin/bash

set -euo pipefail

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
for cmd in git curl; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is not installed. Please install it and try again."
        exit 1
    fi
done

# Check if environment variables are set
if [ -z "${GITHUB_USERNAME:-}" ] || [ -z "${GITHUB_ACCESS_TOKEN:-}" ]; then
    echo "Error: GITHUB_USERNAME and GITHUB_ACCESS_TOKEN must be set in your environment."
    exit 1
fi

# Function to get or prompt for domain name
get_domain_name() {
    if [ -f .domain ]; then
        DOMAIN_NAME=$(cat .domain)
    else
        read -p "Enter the domain name for your website (e.g., example.com): " DOMAIN_NAME
        echo "$DOMAIN_NAME" > .domain
    fi
    REPO_NAME=${DOMAIN_NAME%%.*}
    export DOMAIN_NAME REPO_NAME
}

# Function to setup the website repo
setup_website_repo() {
    local template_repo="website"
    local repo_visibility="private"
    local use_td=false

    # Check if 'td' argument is provided
    if [ "${1:-}" = "td" ]; then
        use_td=true
    fi

    # Prompt the user to choose an existing or new subdirectory
    echo "Choose an existing subdirectory or create a new one:"
    select dir in ~/git/*/ "Create new directory"; do
        if [ "$dir" = "Create new directory" ]; then
            read -p "Enter a new subdirectory name: " subdir_name
            mkdir -p ~/git/$subdir_name
            cd ~/git/$subdir_name
            break
        elif [ -d "$dir" ]; then
            cd "$dir"
            break
        else
            echo "Invalid selection"
        fi
    done

    get_domain_name

    # Check if the repository already exists
    if [ -d "$REPO_NAME" ]; then
        echo "Repository $REPO_NAME already exists. Updating existing repository."
        cd "$REPO_NAME"
    else
        echo "Creating new repository $REPO_NAME."
        mkdir "$REPO_NAME"
        cd "$REPO_NAME"
        git clone https://github.com/$GITHUB_USERNAME/$template_repo.git .

        # Check if the clone was successful
        if [ $? -ne 0 ]; then
            echo "Error: Failed to clone the template repository."
            return 1
        fi

        # Remove the original remote
        git remote remove origin

        # Create a new private repository on GitHub for the user's website
        curl -u $GITHUB_USERNAME:$GITHUB_ACCESS_TOKEN https://api.github.com/user/repos -d '{"name":"'$REPO_NAME'", "private":true}'

        # Add the new remote
        git remote add origin https://github.com/$GITHUB_USERNAME/$REPO_NAME.git
    fi

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

    # Push changes
    git push -u origin main

    echo "Website repo setup complete. Your repo is at https://github.com/$GITHUB_USERNAME/$REPO_NAME"

    # Run main.sh
    if [ "$use_td" = true ]; then
        ./main.sh td
    else
        ./main.sh
    fi
}

# Run the function with command line argument
setup_website_repo "${1:-}"
