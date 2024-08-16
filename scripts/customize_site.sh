#!/bin/bash

set -e

echo "Starting site customization..."

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
sed -i "s/colors\.blue/colors.$color/" next-app/tailwind.config.js
sed -i "s/'light'/'$mode'/" next-app/tailwind.config.js

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

# Update content in index.js
site_name=$(grep NEXT_PUBLIC_SITE_NAME ../.env | cut -d '=' -f2)
site_description=$(grep NEXT_PUBLIC_SITE_DESCRIPTION ../.env | cut -d '=' -f2)

sed -i "s/Welcome to Next.js!/$site_name/" next-app/src/app/page.js
sed -i "s/Get started by editing/Welcome to $site_name - $site_description/" next-app/src/app/page.js

echo "Site customization complete!"