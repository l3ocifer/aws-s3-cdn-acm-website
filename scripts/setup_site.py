# File: scripts/setup_site.py

import os
import subprocess
import logging
from scripts.customize_site import customize_site

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
            'npx', '--yes', 'create-next-app@latest', app_dir,
            '--typescript', '--tailwind', '--eslint',
            '--app', '--src-dir', '--import-alias', '@/*',
            '--use-npm', '--yes'
        ], check=True)
    # Install dependencies
    logging.info("Installing Node.js dependencies...")
    subprocess.run(['npm', 'install'], cwd=app_dir, check=True)

def build_nextjs_app():
    """Build the Next.js app."""
    logging.info("Building Next.js app...")
    subprocess.run(['npm', 'run', 'build'], cwd='next-app', check=True)
    logging.info("Next.js app built successfully.")

def setup_site(domain_name):
    """Set up the website."""
    setup_nextjs_app(domain_name)
    customize_site(domain_name)
    build_nextjs_app()

if __name__ == '__main__':
    import sys
    if len(sys.argv) != 2:
        print("Usage: python setup_site.py <domain_name>")
        sys.exit(1)
    setup_site(sys.argv[1])
