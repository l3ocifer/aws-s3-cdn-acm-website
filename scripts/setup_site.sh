#!/bin/bash
set -euo pipefail

handle_content_file() {
    if [ ! -f ../.content ]; then
        echo "No .content file found. Creating a default one."
        echo "Welcome to $DOMAIN_NAME" > ../.content
    fi
}

handle_logo_file() {
    if [ ! -f ../.logo ]; then
        echo "No .logo file found. Using default logo."
        echo "default" > ../.logo
    fi
}

setup_nextjs_app() {
    if [ -d "next-app" ]; then
        echo "Next.js app already set up. Skipping setup."
        return
    fi

    DOMAIN_NAME=${DOMAIN_NAME:-$(cat ../.domain)}

    echo "Creating Next.js app..."
    npx create-next-app@latest next-app --typescript --eslint --use-npm --tailwind --src-dir --app --import-alias "@/*" --no-git --yes
    cd next-app || exit 1

    # Ensure package.json exists
    if [ ! -f "package.json" ]; then
        echo "Error: package.json not found. Next.js app creation might have failed."
        exit 1
    fi

    # Update package.json scripts
    npm pkg set scripts.build="next build"

    handle_content_file
    handle_logo_file

    mkdir -p src
    jq -n --arg content "$(cat ../.content)" '[{"title": "Welcome", "content": $content}]' > src/content.json

    # Update src/app/layout.tsx
    cat << EOF > src/app/layout.tsx
import './globals.css'
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: '${DOMAIN_NAME}',
  description: 'Welcome to ${DOMAIN_NAME}',
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
EOF

    # Update src/app/page.tsx
    cat << EOF > src/app/page.tsx
import Image from 'next/image'
import content from '../content.json'

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div className="z-10 w-full max-w-5xl items-center justify-between font-mono text-sm lg:flex">
        <p className="fixed left-0 top-0 flex w-full justify-center border-b border-gray-300 bg-gradient-to-b from-zinc-200 pb-6 pt-8 backdrop-blur-2xl dark:border-neutral-800 dark:bg-zinc-800/30 dark:from-inherit lg:static lg:w-auto lg:rounded-xl lg:border lg:bg-gray-200 lg:p-4 lg:dark:bg-zinc-800/30 lg:dark:border-neutral-800">
          Welcome to&nbsp;
          <code className="font-mono font-bold">${DOMAIN_NAME}</code>
        </p>
        <div className="fixed bottom-0 left-0 flex h-48 w-full items-end justify-center bg-gradient-to-t from-white via-white dark:from-black dark:via-black lg:static lg:h-auto lg:w-auto lg:bg-none">

            className="pointer-events-none flex place-items-center gap-2 p-8 lg:pointer-events-auto lg:p-0"
            href="https://${DOMAIN_NAME}"
            target="_blank"
            rel="noopener noreferrer"
          >
            By{' '}
            <Image
              src="/logo.png"
              alt="${DOMAIN_NAME} Logo"
              className="dark:invert"
              width={100}
              height={24}
              priority
            />
          </a>
        </div>
      </div>

      <div className="relative flex place-items-center before:absolute before:h-[300px] before:w-[480px] before:-translate-x-1/2 before:rounded-full before:bg-gradient-radial before:from-white before:to-transparent before:blur-2xl before:content-[''] after:absolute after:-z-20 after:h-[180px] after:w-[240px] after:translate-x-1/3 after:bg-gradient-conic after:from-sky-200 after:via-blue-200 after:blur-2xl after:content-[''] before:dark:bg-gradient-to-br before:dark:from-transparent before:dark:to-blue-700 before:dark:opacity-10 after:dark:from-sky-900 after:dark:via-[#0141ff] after:dark:opacity-40 before:lg:h-[360px]">
        <h1 className="text-4xl font-bold">Welcome to ${DOMAIN_NAME}</h1>
      </div>

      <div className="mb-32 grid text-center lg:max-w-5xl lg:w-full lg:mb-0 lg:grid-cols-4 lg:text-left">
        <div className="group rounded-lg border border-transparent px-5 py-4 transition-colors hover:border-gray-300 hover:bg-gray-100 hover:dark:border-neutral-700 hover:dark:bg-neutral-800/30">
          <h2 className="mb-3 text-2xl font-semibold">
            Welcome
          </h2>
          <p className="m-0 max-w-[30ch] text-sm opacity-50">
            This is your new website. Start customizing it!
          </p>
        </div>
      </div>
    </main>
  )
}
EOF

    # Replace placeholders in page.tsx
    sed -i'' "s/\${DOMAIN_NAME}/$DOMAIN_NAME/g" src/app/page.tsx

    # Update favicon and other icons
    mkdir -p public
    if [ "$(cat ../.logo)" != "default" ]; then
        logo_path=$(cat ../.logo)
        if [[ $logo_path == http* ]]; then
            curl -o public/icon.png "$logo_path"
        else
            cp "$logo_path" public/icon.png
        fi
        npx sharp -i public/icon.png -o public/favicon.ico --format ico
        npx sharp -i public/icon.png -o public/logo.png resize 100 24
        npx sharp -i public/icon.png -o public/apple-touch-icon.png resize 180 180
        for size in 16 32 192 512; do
            npx sharp -i public/icon.png -o "public/icon-${size}x${size}.png" resize "$size" "$size"
        done
    else
        # Create a simple default logo
        convert -size 100x24 xc:white -font Arial -pointsize 12 -fill black -gravity center -draw "text 0,0 '${DOMAIN_NAME}'" public/logo.png
        cp public/logo.png public/icon.png
    fi

    npm install
    cd ..
}

build_nextjs_app() {
    cd next-app
    npm run build
    cd ..
    mv next-app/out public
}

setup_nextjs_app
build_nextjs_app