# File: scripts/setup_site.py

import os
import subprocess
import logging
from scripts.customize_site import customize_site  # Corrected the import
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def setup_nextjs_app(domain_name):
    """Set up the Next.js application."""
    app_dir = 'next-app'
    if os.path.exists(app_dir):
        logging.info("Next.js app already exists. Skipping creation.")
    else:
        logging.info("Creating Next.js app...")
        subprocess.run([
            'npx', 'create-next-app@latest', app_dir,
            '--typescript', '--tailwind', '--eslint',
            '--app', '--src-dir', '--import-alias', '@/*',
            '--use-npm', '--yes'
        ], check=True)
    # Install dependencies
    logging.info("Installing Node.js dependencies...")
    subprocess.run(['npm', 'install'], cwd=app_dir, check=True)
    # Customize the app
    customize_app(domain_name, app_dir)

def customize_app(domain_name, app_dir):
    """Customize the Next.js app with the domain name."""
    # Update next.config.js
    next_config_path = os.path.join(app_dir, 'next.config.js')
    with open(next_config_path, 'w') as f:
        f.write("""
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  images: {
    unoptimized: true,
  },
}

module.exports = nextConfig
""")
    # Update package.json scripts
    package_json_path = os.path.join(app_dir, 'package.json')
    with open(package_json_path, 'r') as f:
        package_json = f.read()
    package_json = package_json.replace('"build": "next build"', '"build": "next build && next export"')
    with open(package_json_path, 'w') as f:
        f.write(package_json)
    # Update index page
    index_page_path = os.path.join(app_dir, 'src', 'app', 'page.tsx')
    os.makedirs(os.path.dirname(index_page_path), exist_ok=True)
    with open(index_page_path, 'w') as f:
        f.write(f"""
export default function Home() {{
  return (
    <main>
      <h1 className="font-bold text-4xl text-gray-900">Welcome to {domain_name}</h1>
    </main>
  )
}}
""")
    logging.info("Customized Next.js app.")

    # Call customize_site.py to further customize the app
    logging.info("Starting site customization...")
    customize_site(domain_name)

def build_nextjs_app():
    """Build the Next.js app."""
    logging.info("Building Next.js app...")
    subprocess.run(['npm', 'run', 'build'], cwd='next-app', check=True)
    logging.info("Next.js app built successfully.")

def setup_site(domain_name):
    """Set up the website."""
    setup_nextjs_app(domain_name)
    build_nextjs_app()

if __name__ == '__main__':
    domain_name = os.getenv('DOMAIN_NAME')
    if not domain_name:
        raise ValueError("DOMAIN_NAME environment variable is not set.")
    setup_site(domain_name)
