#!/usr/bin/env python3
# File: createwebsite.py

import os
import logging
import sys
import subprocess
import shutil
import venv
import atexit

# Set up logging
logging.basicConfig(level=logging.INFO)

def create_venv():
    venv_path = os.path.expanduser('~/.website_creator_venv')
    if not os.path.exists(venv_path):
        logging.info(f"Creating virtual environment at {venv_path}")
        venv.create(venv_path, with_pip=True)
    return venv_path

def activate_venv(venv_path):
    activate_this = os.path.join(venv_path, 'bin', 'activate_this.py')
    exec(open(activate_this).read(), {'__file__': activate_this})

def install_dependencies(venv_path):
    required_packages = ['requests', 'python-dotenv']
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            logging.info(f"Installing {package}...")
            subprocess.check_call([os.path.join(venv_path, 'bin', 'pip'), 'install', package])

def cleanup_venv(venv_path):
    if os.path.exists(venv_path):
        logging.info(f"Cleaning up virtual environment at {venv_path}")
        shutil.rmtree(venv_path)

# Create and activate virtual environment
venv_path = create_venv()
atexit.register(cleanup_venv, venv_path)

# Install dependencies in the virtual environment
activate_venv(venv_path)
install_dependencies(venv_path)

import requests
from dotenv import load_dotenv

# Load environment variables from .env if it exists
if os.path.exists('.env'):
    load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def sanitize_domain_name(domain_name):
    """Sanitize the domain name to create a repo name."""
    # Replace periods before the TLD with underscores
    parts = domain_name.rsplit('.', 1)
    if len(parts) == 2:
        domain_part, tld = parts
        sanitized_domain = domain_part.replace('.', '_')
        repo_name = f"{sanitized_domain}_{tld}"
    else:
        repo_name = domain_name
    # Remove any remaining periods
    repo_name = repo_name.replace('.', '_')
    return repo_name

def create_github_repo(repo_name):
    """Create a new private GitHub repository."""
    GITHUB_USERNAME = os.getenv('GITHUB_USERNAME')
    GITHUB_ACCESS_TOKEN = os.getenv('GITHUB_ACCESS_TOKEN')
    if not GITHUB_USERNAME or not GITHUB_ACCESS_TOKEN:
        logging.error("GitHub username and access token must be set in environment variables 'GITHUB_USERNAME' and 'GITHUB_ACCESS_TOKEN'.")
        sys.exit(1)
    api_url = 'https://api.github.com/user/repos'
    headers = {
        'Authorization': f'token {GITHUB_ACCESS_TOKEN}',
        'Accept': 'application/vnd.github.v3+json'
    }
    data = {
        'name': repo_name,
        'private': True,
        'auto_init': False
    }
    response = requests.post(api_url, headers=headers, json=data)
    if response.status_code == 201:
        logging.info(f"Successfully created GitHub repository '{repo_name}'.")
    elif response.status_code == 422 and 'already exists' in response.text:
        logging.info(f"GitHub repository '{repo_name}' already exists.")
    else:
        logging.error(f"Failed to create GitHub repository '{repo_name}'.")
        logging.error(f"Response: {response.status_code} {response.text}")
        sys.exit(1)

def setup_local_repo(repo_name, template_repo_url):
    """Clone the template repo and set up remotes."""
    GITHUB_USERNAME = os.getenv('GITHUB_USERNAME')
    websites_dir = os.path.expanduser('~/git/websites')
    os.makedirs(websites_dir, exist_ok=True)
    repo_path = os.path.join(websites_dir, repo_name)
    
    if os.path.exists(repo_path):
        logging.info(f"Repository already exists at '{repo_path}'. Updating...")
        os.chdir(repo_path)
        try:
            subprocess.run(['git', 'fetch', 'origin'], check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            logging.warning(f"Failed to fetch from origin: {e.stderr}")
            logging.info("Attempting to set up the repository from scratch...")
            os.chdir(websites_dir)
            shutil.rmtree(repo_path)
            subprocess.run(['git', 'clone', template_repo_url, repo_name], check=True)
            os.chdir(repo_path)
    else:
        # Clone the template repo
        logging.info(f"Cloning template repository '{template_repo_url}' into '{repo_path}'...")
        os.chdir(websites_dir)
        subprocess.run(['git', 'clone', template_repo_url, repo_name], check=True)
        os.chdir(repo_path)
    
    # Create .env file with necessary variables
    create_env_file()
    
    # Check out the main branch
    subprocess.run(['git', 'checkout', '-B', 'main'], check=True)
    
    # Set 'upstream-template' remote
    subprocess.run(['git', 'remote', 'remove', 'upstream-template'], check=False)
    subprocess.run(['git', 'remote', 'add', 'upstream-template', template_repo_url], check=True)
    
    # Set 'origin' to the new GitHub repo using SSH URL
    origin_url = f'git@github.com:{GITHUB_USERNAME}/{repo_name}.git'
    subprocess.run(['git', 'remote', 'remove', 'origin'], check=False)
    subprocess.run(['git', 'remote', 'add', 'origin', origin_url], check=True)
    
    # Verify remotes
    remotes = subprocess.run(['git', 'remote', '-v'], capture_output=True, text=True).stdout
    logging.info(f"Current remotes:\n{remotes}")
    
    # Push to the new origin
    try:
        subprocess.run(['git', 'push', '-u', 'origin', 'main'], check=True, capture_output=True, text=True)
        logging.info(f"Successfully pushed to GitHub repository '{repo_name}'.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to push to origin: {e.stderr}")
        logging.info("Please ensure you have the correct access rights and the repository exists.")
    
    logging.info(f"Set up local repository for '{repo_name}' at '{repo_path}'.")

def create_env_file():
    """Create an .env file with necessary environment variables."""
    DOMAIN_NAME = os.getenv('DOMAIN_NAME')
    REPO_NAME = os.getenv('REPO_NAME')
    GITHUB_USERNAME = os.getenv('GITHUB_USERNAME')
    GITHUB_ACCESS_TOKEN = os.getenv('GITHUB_ACCESS_TOKEN')
    content = f"""# Environment Variables
DOMAIN_NAME={DOMAIN_NAME}
REPO_NAME={REPO_NAME}
GITHUB_USERNAME={GITHUB_USERNAME}
GITHUB_ACCESS_TOKEN={GITHUB_ACCESS_TOKEN}
AWS_PROFILE=default
"""
    with open('.env', 'w') as f:
        f.write(content)
    logging.info("Created .env file with environment variables.")

def main():
    """Entry point for creating a new website."""
    # Get domain name
    domain_name = os.getenv('DOMAIN_NAME')
    if not domain_name:
        domain_name = input("Enter the domain name (must be registered in AWS Route53): ").strip()
    os.environ['DOMAIN_NAME'] = domain_name
    logging.info(f"Using domain name: {domain_name}")

    repo_name = os.getenv('REPO_NAME')
    if not repo_name:
        repo_name = sanitize_domain_name(domain_name)
    os.environ['REPO_NAME'] = repo_name
    logging.info(f"Using repository name: {repo_name}")

    GITHUB_USERNAME = os.getenv('GITHUB_USERNAME')
    GITHUB_ACCESS_TOKEN = os.getenv('GITHUB_ACCESS_TOKEN')
    if not GITHUB_USERNAME or not GITHUB_ACCESS_TOKEN:
        GITHUB_USERNAME = input("Enter your GitHub username: ").strip()
        GITHUB_ACCESS_TOKEN = input("Enter your GitHub access token: ").strip()
        os.environ['GITHUB_USERNAME'] = GITHUB_USERNAME
        os.environ['GITHUB_ACCESS_TOKEN'] = GITHUB_ACCESS_TOKEN

    logging.info(f"Creating/updating repository: {repo_name}")
    
    # Create GitHub repository
    create_github_repo(repo_name)
    
    # Clone the template repository and set up remotes
    template_repo_url = 'git@github.com:l3ocifer/website.git'  # Template repo SSH URL
    setup_local_repo(repo_name, template_repo_url)
    
    # Change to the newly created repository directory
    repo_path = os.path.join(os.path.expanduser('~/git/websites'), repo_name)
    os.chdir(repo_path)
    
    logging.info("Starting main setup process...")
    # Run main script
    subprocess.run([sys.executable, 'scripts/main.py'], check=True)
    
    logging.info(f"Website setup complete for {domain_name}")

if __name__ == '__main__':
    main()
