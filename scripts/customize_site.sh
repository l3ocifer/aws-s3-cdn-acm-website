#!/bin/bash

set -e

echo "Starting site customization..."

# Get the domain name from the command line argument
domain="$1"

if [ -z "$domain" ]; then
    echo "Error: Domain name not provided"
    exit 1
fi

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

# Update tailwind.config.js with selected theme
sed -i.bak "s/colors\.blue/colors.$color/" next-app/tailwind.config.js && rm next-app/tailwind.config.js.bak
sed -i.bak "s/'light'/'$mode'/" next-app/tailwind.config.js && rm next-app/tailwind.config.js.bak

# Comment out image-related operations
: <<'END_COMMENT'
# Generate and optimize images
convert next-app/public/logo.png -resize 32x32 next-app/public/favicon.ico
convert next-app/public/logo.png -resize 180x180 next-app/public/apple-touch-icon.png
convert next-app/public/logo.png -resize 192x192 next-app/public/android-chrome-192x192.png
convert next-app/public/logo.png -resize 512x512 next-app/public/android-chrome-512x512.png

# Optimize images
find next-app/public -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -exec convert {} -strip -quality 85 {} \;
END_COMMENT

# Update content in page.js
site_name="$domain"
site_description="Welcome to $domain"

# Use sed with different delimiters to avoid issues with slashes in variables
sed -i.bak "s|Welcome to Next.js!|Welcome to $site_name|" next-app/src/app/page.js && rm next-app/src/app/page.js.bak
sed -i.bak "s|Get started by editing|$site_description|" next-app/src/app/page.js && rm next-app/src/app/page.js.bak

echo "Site customization complete!"