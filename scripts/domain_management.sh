#!/bin/bash

LAST_DOMAIN_FILE="/tmp/last_website_domain_$$.tmp"

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

setup_website_repo() {
    local use_td=false

    if [ "${1:-}" = "td" ]; then
        use_td=true
    fi

    git remote set-url origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

    echo "$DOMAIN_NAME" > .domain

    if [ ! -f .content ]; then
        echo "Welcome to $DOMAIN_NAME" > .content
    fi

    if [ ! -f .logo ]; then
        echo "default" > .logo
    fi

    git add .
    git commit -m "Update setup for $DOMAIN_NAME" || true

    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "Current branch: $current_branch"

    create_github_repo

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

    chmod +x scripts/*.sh

    run_main_script "$use_td"
}

create_github_repo() {
    if ! curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME" | grep -q "200"; then
        echo "Creating new repository on GitHub..."
        curl -H "Authorization: token $GITHUB_ACCESS_TOKEN" https://api.github.com/user/repos -d '{"name":"'$REPO_NAME'", "private":true}'
    fi
}

run_main_script() {
    local use_td=$1

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

cleanup() {
    rm -f "$LAST_DOMAIN_FILE"
}
