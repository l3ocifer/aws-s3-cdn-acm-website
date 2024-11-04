#!/bin/bash

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_domain() {
    if [[ $# -gt 0 ]]; then
        echo "$1"
        return
    fi
    
    cd terraform
    WEBSITE_URL=$(terraform output -raw website_url)
    cd ..
    echo "${WEBSITE_URL#https://}"
}

setup_landing() {
    local domain=$1
    local name=$(echo "$domain" | sed 's/\.[^.]*$//' | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')
    local dir="leptos-app"
    
    log "Setting up Leptos landing page for $domain"
    
    # Install cargo-leptos and trunk if needed
    if ! command -v cargo-leptos &> /dev/null; then
        log "Installing cargo-leptos..."
        cargo install cargo-leptos
    fi
    if ! command -v trunk &> /dev/null; then
        log "Installing trunk..."
        cargo install trunk
    fi
    
    # Create new Leptos project
    log "Creating new Leptos project..."
    rm -rf "$dir"
    echo "no" | cargo leptos new --git leptos-rs/start --name leptos-app
    
    # Create required directories
    cd "$dir"
    mkdir -p style
    mkdir -p assets

    # Create empty style file to prevent build errors
    touch style/main.scss

    # Build initial project to ensure dependencies are resolved
    cargo build

    log "Setup complete! You can now:"
    log "1. Use 'cargo leptos watch' to start development server"
    log "2. Use 'trunk serve' for client-side development"
    log "3. Use 'cargo leptos build --release' to build for production"
}

# Execute script
setup_landing "$(get_domain "${1:-}")"