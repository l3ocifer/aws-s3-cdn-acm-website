# File: scripts/setup_site.py

import os
import subprocess
import logging
from scripts.customize_site import customize_site

# Set up logging
logging.basicConfig(level=logging.INFO)

def check_node_version():
    """Check if Node.js version meets requirements."""
    try:
        # First try to use nvm to set the correct version
        try:
            subprocess.run(['bash', '-c', 'source ~/.nvm/nvm.sh && nvm use 18.18.0 || nvm install 18.18.0 && nvm use 18.18.0'], check=True)
            return True
        except subprocess.CalledProcessError:
            # If nvm fails, check system node version
            node_version = subprocess.check_output(['node', '--version']).decode().strip().lstrip('v')
            required_version = '18.18.0'
            current_parts = [int(x) for x in node_version.split('.')]
            required_parts = [int(x) for x in required_version.split('.')]
            
            if current_parts < required_parts:
                logging.error(f"Node.js version {node_version} is below required version {required_version}")
                raise ValueError(
                    "Please install Node.js >= 18.18.0 using one of these methods:\n"
                    "1. Install nvm (recommended): https://github.com/nvm-sh/nvm#installing-and-updating\n"
                    "2. Install Node.js directly: https://nodejs.org/\n"
                    "Current Node.js version: {node_version}"
                )
    except Exception as e:
        logging.error(f"Failed to check/update Node.js version: {str(e)}")
        raise
    return True

def setup_nextjs_app(domain_name):
    """Set up the Next.js application."""
    # Check Node.js version before proceeding
    check_node_version()
    
    app_dir = 'next-app'
    if os.path.exists(app_dir):
        logging.info("Next.js app already exists. Skipping creation.")
    else:
        logging.info("Creating Next.js app...")
        # Use the correct Node.js version from nvm for npx
        subprocess.run([
            'bash', '-c',
            'source ~/.nvm/nvm.sh && npx --yes create-next-app@latest next-app --typescript --tailwind --eslint --app --src-dir --import-alias @/* --use-npm --yes'
        ], check=True)
    
    # Install dependencies using the correct Node.js version
    logging.info("Installing Node.js dependencies...")
    subprocess.run(['bash', '-c', 'source ~/.nvm/nvm.sh && cd next-app && npm install'], check=True)

def build_nextjs_app():
    """Build the Next.js app."""
    logging.info("Building Next.js app...")
    # Use the correct Node.js version for building
    subprocess.run(['bash', '-c', 'source ~/.nvm/nvm.sh && cd next-app && npm run build'], check=True)
    logging.info("Next.js app built successfully.")

def setup_site(domain_name):
    """Set up or rebuild the website."""
    app_dir = 'next-app'
    
    # Check if Next.js app exists and is properly initialized
    if not os.path.exists(app_dir) or not os.path.exists(os.path.join(app_dir, 'package.json')):
        logging.info("Setting up new Next.js application...")
        setup_nextjs_app(domain_name)
        customize_site(domain_name)
    else:
        logging.info("Next.js app already exists, checking for changes...")
        # Always customize site to ensure latest changes are applied
        customize_site(domain_name)
    
    # Build the app regardless of whether it's new or existing
    build_nextjs_app()
    logging.info("Site setup/rebuild complete!")

if __name__ == '__main__':
    import sys
    if len(sys.argv) != 2:
        print("Usage: python setup_site.py <domain_name>")
        sys.exit(1)
    setup_site(sys.argv[1])
