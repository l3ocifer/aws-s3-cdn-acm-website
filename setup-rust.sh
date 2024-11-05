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
    cargo new --bin "$dir"
    cd "$dir" || exit 1
    
    # Initialize as a Leptos project with specific versions
    cargo add leptos@0.6.9 --features csr,serde --no-default-features
    cargo add leptos_meta@0.6.9 --features csr --no-default-features
    cargo add log@0.4.20
    cargo add console_log@1.0.0
    cargo add wasm-bindgen@0.2.89
    cargo add web-sys@0.3.67 --features Document,Window,Location,Element,HtmlElement
    cargo add console_error_panic_hook@0.1.7

    # Set up project structure
    mkdir -p src style assets
    touch style/main.scss  # Ensure file exists before writing
    
    # Create main.rs first
    log "Creating main.rs..."
    cat > src/main.rs << 'EOL'
use leptos::*;
use leptos_app::App;

fn main() {
    _ = console_log::init_with_level(log::Level::Debug);
    console_error_panic_hook::set_once();
    mount_to_body(App);
}
EOL

    # Create lib.rs and app.rs
    log "Creating lib.rs and app.rs..."
    cat > src/lib.rs << 'EOL'
pub mod app;
pub use app::*;
EOL

    # Copy template files
    log "Copying template files..."
    cat > style/main.scss << 'EOL'
:root {
    --primary: #00ffff;
    --secondary: #003333;
    --accent: #00cccc;
    --background: #000000;
    --text: #00ffff;
}

body {
    margin: 0;
    padding: 0;
    min-height: 100vh;
    background-color: var(--background);
    color: var(--text);
    font-family: 'Courier New', Courier, monospace;
}

.nav-link {
    color: var(--primary);
    text-decoration: none;
    transition: color 0.3s;
}

.nav-link:hover {
    color: var(--accent);
}

.card {
    border: 1px solid rgba(0, 255, 255, 0.2);
    border-radius: 0.5rem;
    padding: 2rem;
    background: rgba(0, 51, 51, 0.1);
    transition: all 0.3s;
}

.card:hover {
    border-color: rgba(0, 204, 204, 0.4);
}

.heading {
    font-size: 2.25rem;
    font-weight: bold;
    color: var(--primary);
    margin-bottom: 1.5rem;
}

.subheading {
    font-size: 1.5rem;
    font-weight: 600;
    color: var(--accent);
    margin-bottom: 1rem;
}

.description {
    font-size: 1.125rem;
    color: rgba(0, 255, 255, 0.8);
    line-height: 1.75;
}

.container {
    max-width: 72rem;
    margin: 0 auto;
    padding: 0 1rem;
}

.grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 2rem;
}
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
leptos = { version = "0.6.9", features = ["csr", "serde"] }
leptos_meta = { version = "0.6.9", features = ["csr"] }
log = "0.4.20"
console_log = "1.0.0"
wasm-bindgen = "0.2.89"
web-sys = { version = "0.3.67", features = ["Document", "Window", "Location", "Element", "HtmlElement", "Node", "EventTarget"] }
console_error_panic_hook = "0.1.7"
serde = { version = "1.0.196", features = ["derive"] }

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

#[component]
pub fn App() -> impl IntoView {
    view! {
        <div>
            <header style="position: fixed; width: 100%; background: rgba(0, 0, 0, 0.8); backdrop-filter: blur(4px); border-bottom: 1px solid rgba(0, 255, 255, 0.2);">
                <nav class="container" style="height: 5rem; display: flex; align-items: center; justify-content: space-between;">
                    <a href="/" style="font-size: 1.5rem; font-weight: bold; color: var(--primary);">Leptos App</a>
                    <div style="display: flex; gap: 2rem;">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/about" class="nav-link">About</a>
                        <a href="/roadmap" class="nav-link">Roadmap</a>
                        <a href="/contact" class="nav-link">Contact</a>
                    </div>
                </nav>
            </header>

            <main style="padding-top: 8rem; padding-bottom: 4rem;">
                <div class="container">
                    <section style="text-align: center; margin-bottom: 6rem;">
                        <h1 class="heading">Leptos App</h1>
                        <p class="description" style="max-width: 48rem; margin: 0 auto;">
                            A modern web application framework built with Rust
                        </p>
                    </section>

                    <section class="grid">
                        <div class="card">
                            <h2 class="subheading">Fast</h2>
                            <p class="description">Built with performance and reliability.</p>
                        </div>
                        <div class="card">
                            <h2 class="subheading">Simple</h2>
                            <p class="description">Clean, intuitive API for rapid development.</p>
                        </div>
                        <div class="card">
                            <h2 class="subheading">Modern</h2>
                            <p class="description">Leveraging cutting-edge web technologies.</p>
                        </div>
                        <div class="card">
                            <h2 class="subheading">Reliable</h2>
                            <p class="description">Type-safe and memory-safe by design.</p>
                        </div>
                    </section>
                </div>
            </main>
        </div>
    }
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
    mkdir -p end2end/tests
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

    cd "$OLDPWD" || exit 1  # More reliable directory return
    
    log "Setup complete! You can now:"
    log "1. Use 'trunk serve' for development"
    log "2. Use './deploy.sh' for production deployment"
}

# Execute script
setup_rust_site "$(get_domain "${1:-}")" 