#!/bin/bash

set -e

# Create Next.js app if it doesn't exist
if [ ! -d "next-app" ]; then
    npx create-next-app@latest next-app --typescript --eslint --tailwind --app --src-dir --import-alias "@/*" --use-npm
else
    echo "Next.js app already exists, skipping creation."
fi

# Copy necessary files
cp -r templates/* next-app/

# Set up site configuration
site_name=${1:-$(cat .domain)}
site_description=${2:-"Welcome to $site_name"}

# Create or update .config file
echo "SITE_NAME=$site_name" > next-app/.config
echo "SITE_DESCRIPTION=$site_description" >> next-app/.config

# Update Next.js components
sed -i '' "s/SITE_NAME=.*/SITE_NAME=$site_name/" next-app/src/app/page.tsx
sed -i '' "s/SITE_DESCRIPTION=.*/SITE_DESCRIPTION=$site_description/" next-app/src/app/page.tsx

echo "Next.js app setup completed."