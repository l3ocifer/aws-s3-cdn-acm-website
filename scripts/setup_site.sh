#!/bin/bash

set -e

# Use the DOMAIN_NAME environment variable
domain="$DOMAIN_NAME"

if [ -z "$domain" ]; then
    echo "Error: Domain name not provided"
    exit 1
fi

echo "Setting up Next.js app for domain: $domain"

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

handle_content_file() {
    local content_file=".content"
    if [ ! -f "$content_file" ]; then
        echo "Welcome to your new website!" > "$content_file"
    fi
}


handle_config_file() {
    local config_file=".config"
    local last_config="$HOME/.last_website_config"

    if [ ! -f "$config_file" ]; then
        if [ -f "$last_config" ]; then
            cp "$last_config" "$config_file"
        else
            touch "$config_file"
        fi
    fi

    # Read existing config or use defaults
    siteName=$(grep "^siteName=" "$config_file" | cut -d'=' -f2)
    description=$(grep "^description=" "$config_file" | cut -d'=' -f2)

    # Prompt for values, using existing or last used as defaults
    read -p "Enter site name (default: ${siteName:-$DOMAIN_NAME}): " input_siteName
    siteName=${input_siteName:-${siteName:-$DOMAIN_NAME}}

    read -p "Enter site description (default: ${description:-Welcome to $siteName}): " input_description
    description=${input_description:-${description:-Welcome to $siteName}}

    # Update .config file
    sed -i '/^siteName=/d' "$config_file"
    sed -i '/^description=/d' "$config_file"
    echo "siteName=$siteName" >> "$config_file"
    echo "description=$description" >> "$config_file"

    # Save as last used config
    cp "$config_file" "$last_config"
}

update_nextjs_components() {
    # Update src/app/layout.tsx
    cat > src/app/layout.tsx << EOL
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
      <body className={inter.className}>{children}</body>
    </html>
  )
}
EOL

    # Update src/app/page.tsx
    cat > src/app/page.tsx << EOL
import Image from 'next/image'
import data from '../data.json'

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div className="z-10 max-w-5xl w-full items-center justify-between font-mono text-sm lg:flex">
        <p className="fixed left-0 top-0 flex w-full justify-center border-b border-gray-300 bg-gradient-to-b from-zinc-200 pb-6 pt-8 backdrop-blur-2xl dark:border-neutral-800 dark:bg-zinc-800/30 dark:from-inherit lg:static lg:w-auto lg:rounded-xl lg:border lg:bg-gray-200 lg:p-4 lg:dark:bg-zinc-800/30">
          {data.config.description}
        </p>
        <div className="fixed bottom-0 left-0 flex h-48 w-full items-end justify-center bg-gradient-to-t from-white via-white dark:from-black dark:via-black lg:static lg:h-auto lg:w-auto lg:bg-none">
          <a
            className="pointer-events-none flex place-items-center gap-2 p-8 lg:pointer-events-auto lg:p-0"
            href="https://vercel.com?utm_source=create-next-app&utm_medium=appdir-template&utm_campaign=create-next-app"
            target="_blank"
            rel="noopener noreferrer"
          >
            By{' '}
            <Image
              src="/vercel.svg"
              alt="Vercel Logo"
              className="dark:invert"
              width={100}
              height={24}
              priority
            />
          </a>
        </div>
      </div>

      <div className="relative flex place-items-center before:absolute before:h-[300px] before:w-[480px] before:-translate-x-1/2 before:rounded-full before:bg-gradient-radial before:from-white before:to-transparent before:blur-2xl before:content-[''] after:absolute after:-z-20 after:h-[180px] after:w-[240px] after:translate-x-1/3 after:bg-gradient-conic after:from-sky-200 after:via-blue-200 after:blur-2xl after:content-[''] before:dark:bg-gradient-to-br before:dark:from-transparent before:dark:to-blue-700 before:dark:opacity-10 after:dark:from-sky-900 after:dark:via-[#0141ff] after:dark:opacity-40 before:lg:h-[360px] z-[-1]">
        <Image
          className="relative dark:drop-shadow-[0_0_0.3rem_#ffffff70] dark:invert"
          src="/next.svg"
          alt="Next.js Logo"
          width={180}
          height={37}
          priority
        />
      </div>

      <div className="mb-32 grid text-center lg:max-w-5xl lg:w-full lg:mb-0 lg:grid-cols-4 lg:text-left">
        {data.content.map((item, index) => (
          <div key={index} className="group rounded-lg border border-transparent px-5 py-4 transition-colors hover:border-gray-300 hover:bg-gray-100 hover:dark:border-neutral-700 hover:dark:bg-neutral-800/30">
            <h2 className="mb-3 text-2xl font-semibold">{item.title}</h2>
            <p className="m-0 max-w-[30ch] text-sm opacity-50">{item.content}</p>
          </div>
        ))}
      </div>
    </main>
  )
}
EOL
}