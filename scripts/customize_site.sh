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

# Update tailwind.config.ts with selected theme if it exists
if [ -f "next-app/tailwind.config.ts" ]; then
    sed -i.bak "s/colors\.blue/colors.$color/" next-app/tailwind.config.ts && rm next-app/tailwind.config.ts.bak
    sed -i.bak "s/'light'/'$mode'/" next-app/tailwind.config.ts && rm next-app/tailwind.config.ts.bak
    echo "Updated tailwind.config.ts with selected theme and mode."
else
    echo "tailwind.config.ts not found. Skipping theme update."
fi

# Update content in page.tsx if it exists
if [ -f "next-app/src/app/page.tsx" ]; then
    # Instead of modifying content, we'll just update the color theme
    sed -i.bak "s/className=\".*\"/className=\"text-$color-600\"/" next-app/src/app/page.tsx && rm next-app/src/app/page.tsx.bak
    echo "Updated page.tsx with selected color theme."
else
    echo "page.tsx not found. Skipping content update."
fi

echo "Site customization complete!"