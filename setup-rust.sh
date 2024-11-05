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

setup_rust_site() {
    local domain=$1
    local name=$(echo "$domain" | sed 's/\.[^.]*$//' | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')
    local dir="leptos-app"
    
    log "Setting up Leptos site for $domain"
    
    # Install required tools
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
    cargo leptos new "$dir" --git leptos-rs/start-axum
    cd "$dir"
    cargo add leptos@0.6.9 --features csr
    cargo add leptos_meta@0.6.9 --features csr
    cargo remove actix-files actix-web
    cargo remove tokio --features macros,rt-multi-thread
    cargo remove leptos_actix
    
    # Create required directories
    mkdir -p {style,assets,end2end/tests}
    
    # Setup npm and tailwind
    log "Setting up Tailwind CSS..."
    npm init -y
    npm install -D tailwindcss@latest postcss@latest autoprefixer@latest
    npx tailwindcss init -p
    
    # Copy template files
    log "Copying template files..."
    cat > style/main.scss << 'EOL'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
    --primary: #00ffff;
    --secondary: #003333;
    --accent: #00cccc;
    --background: #000000;
    --text: #00ffff;
    --max-width: 1200px;
    --header-height: 80px;
    --section-spacing: 120px;
}

// ... rest of main.scss content ...
EOL

    # Update Cargo.toml
    log "Updating Cargo.toml..."
    cat > Cargo.toml << 'EOL'
[package]
name = "leptos-app"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
leptos = { version = "0.6.9", features = ["csr"] }
leptos_meta = { version = "0.6.9", features = ["csr"] }
log = "0.4.20"
console_log = "1.0.0"
wasm-bindgen = "0.2.89"
web-sys = { version = "0.3.67", features = [
    "Document", 
    "Window", 
    "Location", 
    "Element", 
    "ScrollBehavior",
    "ScrollIntoViewOptions"
]}
console_error_panic_hook = "0.1.7"
urlencoding = "2.1.3"

[features]
default = ["csr"]
csr = ["leptos/csr", "leptos_meta/csr"]
hydrate = ["leptos/hydrate", "leptos_meta/hydrate"]

[package.metadata.leptos]
output-name = "leptos-app"
site-root = "target/site"
site-pkg-dir = "pkg"
style-file = "style/main.scss"
assets-dir = "assets"
site-addr = "127.0.0.1:3000"
reload-port = 3001
env = "PROD"
bin-features = ["csr"]
lib-features = ["csr"]
bin-default-features = false
lib-default-features = false
browserquery = "defaults"
watch = false
site-serve-command = "trunk serve"
copy-file = ["index.html"]
EOL

    # Copy template app.rs
    log "Creating app.rs..."
    cat > src/app.rs << 'EOL'
use leptos::*;
use leptos_meta::*;

#[component]
pub fn App() -> impl IntoView {
    // ... rest of app.rs content ...
}
EOL

    # Create index.html
    log "Creating index.html..."
    cat > index.html << 'EOL'
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>author.works</title>
    <link data-trunk rel="rust" data-bin="leptos-app" data-wasm-opt="z" />
    <link data-trunk rel="scss" href="style/main.scss" />
    <link data-trunk rel="copy-dir" href="assets" />
    <style>
      :root {
        --primary: #00ffff;
        --secondary: #003333;
        --accent: #00cccc;
        --background: #000000;
        --text: #00ffff;
      }
      
      html, body {
        margin: 0;
        padding: 0;
        min-height: 100vh;
        background-color: var(--background);
        color: var(--text);
        font-family: 'Courier New', Courier, monospace;
      }
    </style>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
EOL

    # Setup e2e tests
    log "Setting up end-to-end tests..."
    cat > end2end/tests/example.spec.ts << 'EOL'
import { test, expect } from "@playwright/test";

test("homepage has title and links to intro page", async ({ page }) => {
  await page.goto("http://localhost:3000/");
  await expect(page).toHaveTitle("author.works");
});
EOL

    # Initial build
    log "Running initial build..."
    cargo build
    
    log "Setup complete! You can now:"
    log "1. Use 'trunk serve' for development"
    log "2. Use './deploy.sh' for production deployment"
}

# Execute script
setup_rust_site "$(get_domain "${1:-}")" 