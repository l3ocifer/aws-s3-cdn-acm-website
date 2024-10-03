# File: createwebsite.py

import os
import logging
import sys
import subprocess
import requests

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
    GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
    if not GITHUB_USERNAME or not GITHUB_TOKEN:
        logging.error("GitHub username and token must be set in environment variables 'GITHUB_USERNAME' and 'GITHUB_TOKEN'.")
        sys.exit(1)
    api_url = 'https://api.github.com/user/repos'
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
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
    repo_path = os.path.join(os.getcwd(), repo_name)
    if os.path.exists(repo_path):
        logging.info(f"Repository already exists at '{repo_path}'.")
    else:
        # Clone the template repo
        logging.info(f"Cloning template repository '{template_repo_url}' into '{repo_path}'...")
        subprocess.run(['git', 'clone', template_repo_url, repo_name], check=True)
    
    # Change directory to the repo
    os.chdir(repo_path)
    
    # Create .env file with necessary variables
    create_env_file()
    
    # Check out the main branch
    subprocess.run(['git', 'checkout', '-B', 'main'], check=True)
    
    # Set 'upstream-template' remote
    subprocess.run(['git', 'remote', 'rename', 'origin', 'upstream-template'], check=True)
    # Set 'origin' to the new GitHub repo using SSH URL
    origin_url = f'git@github.com:{GITHUB_USERNAME}/{repo_name}.git'
    subprocess.run(['git', 'remote', 'add', 'origin', origin_url], check=True)
    
    # Push to the new origin
    subprocess.run(['git', 'push', '-u', 'origin', 'main'], check=True)
    logging.info(f"Set up local repository and pushed to GitHub repository '{repo_name}'.")

def create_env_file():
    """Create an .env file with necessary environment variables."""
    DOMAIN_NAME = os.getenv('DOMAIN_NAME')
    REPO_NAME = os.getenv('REPO_NAME')
    GITHUB_USERNAME = os.getenv('GITHUB_USERNAME')
    content = f"""# Environment Variables
DOMAIN_NAME={DOMAIN_NAME}
REPO_NAME={REPO_NAME}
GITHUB_USERNAME={GITHUB_USERNAME}
AWS_PROFILE=default
"""
    with open('.env', 'w') as f:
        f.write(content)
    logging.info("Created .env file with environment variables.")

def main():
    """Entry point for creating a new website."""
    # Get domain name
    domain_name = input("Enter the domain name (must be registered in AWS Route53): ").strip()
    os.environ['DOMAIN_NAME'] = domain_name
    repo_name = sanitize_domain_name(domain_name)
    os.environ['REPO_NAME'] = repo_name
    
    GITHUB_USERNAME = os.getenv('GITHUB_USERNAME')
    GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
    if not GITHUB_USERNAME or not GITHUB_TOKEN:
        logging.error("GitHub username and token must be set in environment variables 'GITHUB_USERNAME' and 'GITHUB_TOKEN'.")
        sys.exit(1)
    
    # Create GitHub repository
    create_github_repo(repo_name)
    
    # Clone the template repository and set up remotes
    template_repo_url = 'git@github.com:l3ocifer/website.git'  # Template repo SSH URL
    setup_local_repo(repo_name, template_repo_url)
    
    # Run main script
    from scripts.main import main as setup_main
    setup_main()
    
if __name__ == '__main__':
    main()
