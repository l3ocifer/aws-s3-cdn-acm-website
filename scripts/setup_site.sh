#!/bin/bash

set -e

# Use the DOMAIN_NAME environment variable
domain="$DOMAIN_NAME"

if [ -z "$domain" ]; then
    echo "ERROR: Domain name not provided" >&2
    exit 1
fi

echo "Setting up Next.js app for domain: $domain"

# Handle .config file
config_file=".config"
if [ ! -f "$config_file" ]; then
    echo "siteName=${domain}" > "$config_file"
    echo "description=Welcome to ${domain}" >> "$config_file"
    echo "Created .config file"
else
    echo ".config file already exists"
fi

# Handle .content file
content_file=".content"
if [ ! -f "$content_file" ]; then
    echo "Welcome to your new website!" > "$content_file"
    echo "Created .content file"
else
    echo ".content file already exists"
fi

# Check if next-app directory exists
if [ -d "next-app" ]; then
    echo "next-app directory already exists. Updating existing app..."
    cd next-app

    # Update dependencies
    npm install
    npm install @headlessui/react @heroicons/react

    # Check if ../src directory exists before copying
    if [ -d "../src" ]; then
        echo "Updating source files..."
        cp -R ../src/* src/
    else
        echo "No ../src directory found. Skipping source file update."
    fi

    cd ..
else
    # Create Next.js app
    npx create-next-app@latest next-app --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

    # Change to the next-app directory
    cd next-app

    # Install additional dependencies
    npm install @headlessui/react @heroicons/react

    # Check if ../src directory exists before copying
    if [ -d "../src" ]; then
        echo "Copying source files..."
        cp -R ../src/* src/
    else
        echo "No ../src directory found. Skipping source file copy."
    fi

    # Return to the parent directory
    cd ..
fi

# Run the customize_site script
./scripts/customize_site.sh

echo "Next.js app setup complete for $domain!"