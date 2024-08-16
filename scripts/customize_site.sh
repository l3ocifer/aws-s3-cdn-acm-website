#!/bin/bash

set -e

echo "Starting site customization..."

# Use the DOMAIN_NAME environment variable
domain="$DOMAIN_NAME"

if [ -z "$domain" ]; then
    echo "Error: Domain name not provided"
    exit 1
fi

echo "Customizing site for domain: $domain"

# Choose color theme
echo "Choose a primary color theme:"
select color in "yellow" "violet" "orange" "blue" "red" "indigo" "green"; do
    if [[ -n $color ]]; then
        break
    fi
done

# Choose mode
echo "Choose a mode:"
select mode in "light" "dark"; do
    if [[ -n $mode ]]; then
        break
    fi
done

echo "Generating site content..."

# Update tailwind.config.js with selected theme if it exists
if [ -f "next-app/tailwind.config.js" ]; then
    sed -i.bak "s/colors\.blue/colors.$color/" next-app/tailwind.config.js && rm next-app/tailwind.config.js.bak
    sed -i.bak "s/'light'/'$mode'/" next-app/tailwind.config.js && rm next-app/tailwind.config.js.bak
else
    echo "tailwind.config.js not found. Skipping theme update."
fi

# Update content in page.js if it exists
if [ -f "next-app/src/app/page.js" ]; then
    site_name="$domain"
    site_description="Welcome to $domain"

    # Use sed with different delimiters to avoid issues with slashes in variables
    sed -i.bak "s|Welcome to Next.js!|Welcome to $site_name|" next-app/src/app/page.js && rm next-app/src/app/page.js.bak
    sed -i.bak "s|Get started by editing|$site_description|" next-app/src/app/page.js && rm next-app/src/app/page.js.bak
else
    echo "page.js not found. Skipping content update."
fi

echo "Site customization complete!"