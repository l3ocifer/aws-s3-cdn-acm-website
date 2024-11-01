# File: scripts/setup_site.py

import os
import subprocess
import logging
from scripts.customize_site import customize_site

# Set up logging
logging.basicConfig(level=logging.INFO)

def check_node_version():
    """Check if Node.js version meets requirements and set it."""
    try:
        # First ensure nvm is loaded and the correct version is installed
        setup_cmd = (
            'export NVM_DIR="$HOME/.nvm" && '
            '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && '
            'nvm install 18.18.0 > /dev/null 2>&1 && '
            'nvm alias default 18.18.0 > /dev/null 2>&1 && '
            'nvm use default > /dev/null 2>&1 && '
            'PATH="$NVM_DIR/versions/node/v18.18.0/bin:$PATH" && '
            'hash -r && '
            'node --version'
        )
        node_version = subprocess.check_output(['bash', '-c', setup_cmd], text=True).strip()
        
        if not node_version.startswith('v18.18.0'):
            raise ValueError(f"Node.js version mismatch. Got {node_version}, expected v18.18.0")
        
        # Update environment PATH to include the correct Node.js version
        os.environ['PATH'] = f"{os.path.expanduser('~/.nvm/versions/node/v18.18.0/bin')}:{os.environ.get('PATH', '')}"
        
        logging.info(f"Using Node.js version: {node_version}")
        return True
    except Exception as e:
        logging.error(f"Failed to set up Node.js version: {str(e)}")
        raise

def setup_nextjs_app(domain_name):
    """Set up the Next.js application."""
    # Check Node.js version before proceeding
    check_node_version()
    
    app_dir = 'next-app'
    if os.path.exists(app_dir):
        logging.info("Next.js app already exists. Skipping creation.")
    else:
        logging.info("Creating Next.js app...")
        create_cmd = (
            'export NVM_DIR="$HOME/.nvm" && '
            '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && '
            'PATH="$NVM_DIR/versions/node/v18.18.0/bin:$PATH" && '
            'hash -r && '
            'npx --yes create-next-app@latest next-app '
            '--typescript --tailwind --eslint --app --src-dir --import-alias @/* --use-npm --yes'
        )
        subprocess.run(['bash', '-c', create_cmd], check=True)
        
        # Add Next.js app to git
        logging.info("Adding Next.js app to git...")
        subprocess.run(['git', 'add', 'next-app'], check=True)
        subprocess.run(['git', 'commit', '-m', 'initial next.js app setup'], check=True)
        subprocess.run(['git', 'push'], check=True)
    
    # Install dependencies using the correct Node.js version
    logging.info("Installing Node.js dependencies...")
    install_cmd = (
        'export NVM_DIR="$HOME/.nvm" && '
        '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && '
        'PATH="$NVM_DIR/versions/node/v18.18.0/bin:$PATH" && '
        'hash -r && '
        'cd next-app && npm install'
    )
    subprocess.run(['bash', '-c', install_cmd], check=True)

def build_nextjs_app():
    """Build the Next.js app."""
    logging.info("Building Next.js app...")
    build_cmd = (
        'export NVM_DIR="$HOME/.nvm" && '
        '[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh" && '
        'PATH="$NVM_DIR/versions/node/v18.18.0/bin:$PATH" && '
        'hash -r && '
        'cd next-app && '
        'npm install && '
        'npm run build'
    )
    subprocess.run(['bash', '-c', build_cmd], check=True)
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
