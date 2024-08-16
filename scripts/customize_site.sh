#!/bin/bash

source ./scripts/utils.sh

# Color themes with complementary colors
declare -A color_themes
color_themes=(
    ["red"]="primary:#FF0000,secondary:#00FFFF,accent:#FF00FF,text:#333333,background:#FFFFFF"
    ["orange"]="primary:#FFA500,secondary:#0080FF,accent:#40E0D0,text:#333333,background:#FFFFFF"
    ["yellow"]="primary:#FFFF00,secondary:#8B00FF,accent:#00CED1,text:#333333,background:#FFFFFF"
    ["green"]="primary:#00FF00,secondary:#FF00FF,accent:#FFD700,text:#333333,background:#FFFFFF"
    ["blue"]="primary:#0000FF,secondary:#FFA500,accent:#32CD32,text:#333333,background:#FFFFFF"
    ["indigo"]="primary:#4B0082,secondary:#FFD700,accent:#00FA9A,text:#FFFFFF,background:#333333"
    ["violet"]="primary:#8A2BE2,secondary:#FFFF00,accent:#FF4500,text:#FFFFFF,background:#333333"
)

choose_color_theme() {
    echo "Choose a primary color theme:"
    select color in "${!color_themes[@]}"; do
        if [[ -n "$color" ]]; then
            echo "You selected $color"
            IFS=',' read -ra color_array <<< "${color_themes[$color]}"
            for color_pair in "${color_array[@]}"; do
                IFS=':' read -r key value <<< "$color_pair"
                colors[$key]=$value
            done
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

choose_mode() {
    echo "Choose a mode:"
    select mode in "light" "dark"; do
        if [[ -n "$mode" ]]; then
            echo "You selected $mode mode"
            if [[ "$mode" == "dark" ]]; then
                colors[background]=${colors[text]}
                colors[text]=${colors[background]}
            fi
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

# Function to get API key
get_api_key() {
    local key_name="$1"
    local env_var_name="$2"
    local api_key

    if [ -n "${!env_var_name}" ]; then
        api_key="${!env_var_name}"
    else
        read -p "Enter your $key_name API key: " api_key
        export "$env_var_name=$api_key"
    fi

    echo "$api_key"
}

# Function to generate content using AI
generate_ai_content() {
    local prompt="$1"
    local api_key=$(get_api_key "OpenAI" "OPENAI_API_KEY")
    local response=$(curl -s -H "Authorization: Bearer $api_key" \
         -H "Content-Type: application/json" \
         -d "{
           \"model\": \"gpt-3.5-turbo\",
           \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
           \"max_tokens\": 150
         }" \
         https://api.openai.com/v1/chat/completions)
    echo "$response" | jq -r '.choices[0].message.content'
}

# Function to generate image using AI
generate_ai_image() {
    local prompt="$1"
    local api_key=$(get_api_key "OpenAI" "OPENAI_API_KEY")
    local response=$(curl -s -H "Authorization: Bearer $api_key" \
         -H "Content-Type: application/json" \
         -d "{
           \"prompt\": \"$prompt\",
           \"n\": 1,
           \"size\": \"512x512\"
         }" \
         https://api.openai.com/v1/images/generations)
    echo "$response" | jq -r '.data[0].url'
}

# Function to get content (AI-generated or user input)
get_content() {
    local prompt="$1"
    local content_type="$2"
    local content

    read -p "Do you want to use AI to generate $content_type? (y/n): " use_ai
    if [[ $use_ai == "y" ]]; then
        content=$(generate_ai_content "$prompt")
    else
        read -p "Enter the $content_type manually or provide a file path: " input
        if [ -f "$input" ]; then
            content=$(cat "$input")
        else
            content="$input"
        fi
    fi

    echo "$content"
}

# Function to get image (AI-generated, user input, or default)
get_image() {
    local prompt="$1"
    local image_type="$2"
    local default_image="next-app/public/default-logo.png"
    local image_path

    read -p "Do you want to use AI to generate $image_type? (y/n): " use_ai
    if [[ $use_ai == "y" ]]; then
        local image_url=$(generate_ai_image "$prompt")
        image_path="next-app/public/${image_type}.png"
        if curl -s "$image_url" -o "$image_path"; then
            log "AI-generated image saved as $image_path"
        else
            warn "Failed to download AI-generated image. Using default."
            image_path="$default_image"
        fi
    else
        read -p "Enter the path to your $image_type image (or press Enter for default): " user_image_path
        if [ -n "$user_image_path" ] && [ -f "$user_image_path" ]; then
            image_path="$user_image_path"
        else
            warn "Invalid image path or no image provided. Using default."
            image_path="$default_image"
        fi
    fi

    # Ensure the default image exists
    if [ ! -f "$image_path" ]; then
        log "Creating default logo..."
        create_default_logo "$default_image"
        image_path="$default_image"
    fi

    echo "$image_path"
}

# Function to create a simple default logo
create_default_logo() {
    local default_image="$1"
    local site_name=$(grep '^siteName=' .config | cut -d'=' -f2)
    
    # Use ImageMagick to create a simple text-based logo
    convert -size 200x100 xc:transparent -fill "${colors[primary]}" \
        -gravity center -pointsize 24 -annotate 0 "$site_name" "$default_image"
    
    log "Created default logo: $default_image"
}

# Function to get favicon from logo
create_favicon() {
    local logo="$1"
    local favicon="$2"
    convert "$logo" -resize 32x32 "$favicon"
}

customize_site() {
    log "Starting site customization..."

    choose_color_theme
    choose_mode

    # Generate site content
    log "Generating site content..."
    local site_name=$(grep '^siteName=' .config | cut -d'=' -f2)
    local content=$(get_content "Write a short welcome message for a website called $site_name" "welcome message")
    echo "$content" > .content

    # Generate about page
    log "Generating about page..."
    local about_content=$(get_content "Write a brief 'About Us' section for $site_name website" "About Us content")

    # Generate logo
    log "Generating logo..."
    local logo_path=$(get_image "Create a simple, modern logo for $site_name website, using ${colors[primary]} as the primary color" "logo")
    echo "$logo_path" > .logo

    # Generate favicon
    log "Generating favicon..."
    create_favicon "$logo_path" "next-app/public/favicon.ico"

    # Update Next.js components
    update_nextjs_components "$about_content"

    log "Site customization completed successfully!"
}

update_nextjs_components() {
    local about_content="$1"
    local logo_path=$(cat .logo)

    # Update globals.css with color theme and mode
    cat > next-app/src/app/globals.css << EOL
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --primary-color: ${colors[primary]};
  --secondary-color: ${colors[secondary]};
  --accent-color: ${colors[accent]};
  --text-color: ${colors[text]};
  --background-color: ${colors[background]};
}

body {
  background-color: var(--background-color);
  color: var(--text-color);
}
EOL

    # Update layout.tsx
    cat > next-app/src/app/layout.tsx << EOL
import './globals.css'
import { Inter } from 'next/font/google'
import data from '../data.json'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: data.config.siteName,
  description: data.config.description,
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/favicon.ico" />
      </head>
      <body className={inter.className}>{children}</body>
    </html>
  )
}
EOL

    # Update src/app/page.tsx to use the logo
    sed -i "s|src=\"/logo.png\"|src=\"${logo_path}\"|" next-app/src/app/page.tsx

    # Create about page
    mkdir -p next-app/src/app/about
    cat > next-app/src/app/about/page.tsx << EOL
import React from 'react'

export default function AboutPage() {
    return (
        <div className="container mx-auto px-4 py-8">
            <h1 className="text-3xl font-bold mb-4">About Us</h1>
            <p className="text-lg">${about_content}</p>
        </div>
    )
}
EOL

    log "Next.js components updated."
}

customize_site