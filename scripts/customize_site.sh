#!/bin/bash

set -e

# Function to check and install ImageMagick
check_and_install_imagemagick() {
    if ! command -v magick &> /dev/null; then
        echo "ImageMagick not found. Attempting to install..."
        if command -v brew &> /dev/null; then
            brew install imagemagick
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y imagemagick
        elif command -v yum &> /dev/null; then
            sudo yum install -y ImageMagick
        else
            echo "Error: Unable to install ImageMagick. Please install it manually and try again."
            exit 1
        fi
    fi
}

# Function to get favicon from logo
create_favicon() {
    local logo="$1"
    local favicon="$2"
    magick convert "$logo" -resize 32x32 "$favicon"
}

# Function to handle logo file
handle_logo_file() {
    local logo_file=".logo"
    if [ ! -f "$logo_file" ]; then
        create_default_logo "public/default-logo.png"
        echo "public/default-logo.png" > "$logo_file"
    fi
}

# Function to create default logo
create_default_logo() {
    local output_path="$1"
    magick -size 200x200 xc:white -font Arial -pointsize 40 -fill black -gravity center -annotate 0 "Default Logo" "$output_path"
}

# Main execution starts here
echo "Starting site customization..."

# Check and install ImageMagick if necessary
check_and_install_imagemagick

# Set up color theme and mode
echo "Choose a primary color theme:"
select color in "yellow" "violet" "orange" "blue" "red" "indigo" "green"; do
    if [ -n "$color" ]; then
        break
    fi
done

echo "Choose a mode:"
select mode in "light" "dark"; do
    if [ -n "$mode" ]; then
        break
    fi
done

echo "Generating site content..."

# Handle logo file
handle_logo_file

# Generate favicon
logo_path=$(cat .logo)
create_favicon "$logo_path" "public/favicon.ico"

echo "Generating favicon..."

# Update Next.js components
sed -i '' "s/primary_color = '.*'/primary_color = '$color'/" next-app/src/app/page.tsx
sed -i '' "s/mode = '.*'/mode = '$mode'/" next-app/src/app/page.tsx

echo "Next.js components updated."
echo "Site customization completed successfully!"