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

colors=("yellow" "violet" "orange" "blue" "red" "indigo" "green")
echo "Choose a primary color theme:"
select color in "${colors[@]}"; do
    if [[ -n $color ]]; then
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

modes=("light" "dark")
echo "Choose a mode:"
select mode in "${modes[@]}"; do
    if [[ -n $mode ]]; then
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

echo "Generating site content..."

# Update tailwind.config.ts
config_file="next-app/tailwind.config.ts"
awk '
/extend: \{\}/ {
    print "  extend: {";
    print "    colors: {";
    print "      primary: \"var(--color-primary)\",";
    print "    },";
    print "  },";
    next
}
{ print }
' "$config_file" > temp_file && mv temp_file "$config_file"
echo "Updated tailwind.config.ts with selected theme and mode."

# Update page.tsx
page_file="next-app/src/app/page.tsx"
awk '
/className=\{`font-bold text-4xl text-gray-900`\}/ {
    gsub(/text-gray-900/, "text-primary")
}
{ print }
' "$page_file" > temp_file && mv temp_file "$page_file"
echo "Updated page.tsx with selected color theme."

echo "Site customization complete!"
echo "Next.js app setup complete for $domain!"