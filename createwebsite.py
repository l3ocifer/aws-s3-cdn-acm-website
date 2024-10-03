# File: createwebsite.py

import os
import logging
import sys
import shutil
import subprocess

from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def clone_template_repo(repo_url, target_dir):
    """Clone the template repository."""
    if os.path.exists(target_dir):
        logging.info(f"Repository already exists at '{target_dir}'.")
    else:
        logging.info(f"Cloning repository '{repo_url}' into '{target_dir}'...")
        subprocess.run(['git', 'clone', repo_url, target_dir], check=True)

def main():
    """Entry point for creating a new website."""
    # Get domain name
    domain_name = input("Enter the domain name: ")
    os.environ['DOMAIN_NAME'] = domain_name
    repo_name = domain_name.replace('.', '-')
    os.environ['REPO_NAME'] = repo_name
    
    # Clone the template repository
    template_repo_url = 'https://github.com/yourusername/website-template.git'  # Replace with actual template repo URL
    repo_path = os.path.join(os.getcwd(), repo_name)
    clone_template_repo(template_repo_url, repo_path)
    
    # Change directory to the repository
    os.chdir(repo_path)
    
    # Run main script
    from scripts.main import main as setup_main
    setup_main()
    
if __name__ == '__main__':
    main()
