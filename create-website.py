#!/usr/bin/env python3
# File: createwebsite.py

import os
import logging
import sys
import subprocess
import shutil
import atexit
import venv
import argparse
import json

# Set up logging
logging.basicConfig(level=logging.INFO)

def create_venv():
    venv_path = os.path.expanduser('~/.website_creator_venv')
    if not os.path.exists(venv_path):
        logging.info(f"Creating virtual environment at {venv_path}")
        try:
            venv.create(venv_path, with_pip=True)
            # Ensure pip is installed and updated
            subprocess.run([os.path.join(venv_path, 'bin', 'python'), '-m', 'ensurepip', '--upgrade'], check=True)
            subprocess.run([os.path.join(venv_path, 'bin', 'python'), '-m', 'pip', 'install', '--upgrade', 'pip'], check=True)
        except Exception as e:
            logging.error(f"Failed to create virtual environment: {str(e)}")
            raise
    return venv_path

def install_dependencies(pip_executable):
    required_packages = ['requests', 'python-dotenv', 'boto3']
    for package in required_packages:
        subprocess.run([pip_executable, 'install', package], check=True)

def cleanup_venv(venv_path):
    if os.path.exists(venv_path):
        logging.info(f"Cleaning up virtual environment at {venv_path}")
        shutil.rmtree(venv_path)

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
    import urllib.request
    import json

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
    data = json.dumps({
        'name': repo_name,
        'private': True,
        'auto_init': False
    }).encode('utf-8')
    req = urllib.request.Request(api_url, data=data, headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 201:
                logging.info(f"Successfully created GitHub repository '{repo_name}'.")
            else:
                response_body = response.read().decode('utf-8')
                logging.error(f"Failed to create GitHub repository '{repo_name}'.")
                logging.error(f"Response: {response.status} {response_body}")
                sys.exit(1)
    except urllib.error.HTTPError as e:
        error_message = e.read().decode('utf-8')
        if e.code == 422 and 'already exists' in error_message:
            logging.info(f"GitHub repository '{repo_name}' already exists.")
        else:
            logging.error(f"Failed to create GitHub repository '{repo_name}'.")
            logging.error(f"Response: {e.code} {error_message}")
            sys.exit(1)

def get_last_domain():
    domain_file = os.path.expanduser('~/.last_website_domain')
    if os.path.exists(domain_file):
        with open(domain_file, 'r') as f:
            return f.read().strip()
    return None

def save_last_domain(domain):
    domain_file = os.path.expanduser('~/.last_website_domain')
    with open(domain_file, 'w') as f:
        f.write(domain)

def setup_local_repo(repo_name, template_repo_url):
    """Set up the local repository and add the template as upstream."""
    GITHUB_USERNAME = os.getenv('GITHUB_USERNAME')
    websites_dir = os.path.expanduser('~/git/websites')
    repo_path = os.path.join(websites_dir, repo_name)

    # Remove existing repo directory if it exists
    if os.path.exists(repo_path):
        shutil.rmtree(repo_path)

    # Clone the repository (this will work for both existing and newly created repos)
    subprocess.run(['git', 'clone', f'git@github.com:{GITHUB_USERNAME}/{repo_name}.git', repo_path], check=True)
    os.chdir(repo_path)

    # Add template repository as upstream
    subprocess.run(['git', 'remote', 'add', 'upstream-template', template_repo_url], check=True)

    # Fetch template content
    subprocess.run(['git', 'fetch', 'upstream-template'], check=True)

    # Check if the local repository is empty
    result = subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True)
    if result.returncode != 0:
        # If the repository is empty, create an initial commit on master branch
        subprocess.run(['git', 'checkout', '-b', 'master'], check=True)
        subprocess.run(['git', 'commit', '--allow-empty', '-m', "Initial commit"], check=True)

    # Merge template content into the master branch
    subprocess.run(['git', 'merge', 'upstream-template/master', '--allow-unrelated-histories', '-m', "Merge template into master"], check=True)

    # Push changes to the repository
    subprocess.run(['git', 'push', '-u', 'origin', 'master'], check=True)

    # Log current remotes
    result = subprocess.run(['git', 'remote', '-v'], capture_output=True, text=True, check=True)
    logging.info(f"Current remotes:\n{result.stdout}")

    logging.info(f"Successfully set up local repository for '{repo_name}' at '{repo_path}'.")

def get_terraform_variable(var_name):
    try:
        output = subprocess.check_output(['terraform', 'output', '-raw', var_name], cwd='terraform')
        return output.decode('utf-8').strip()
    except subprocess.CalledProcessError:
        return None

def main():
    """Entry point for creating a new website."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--venv-activated', action='store_true', help='Indicates the script is running inside the virtual environment')
    args = parser.parse_args()

    if not args.venv_activated:
        # Create and activate virtual environment
        venv_path = create_venv()
        atexit.register(cleanup_venv, venv_path)
        try:
            # Install dependencies in the virtual environment
            pip_executable = os.path.join(venv_path, 'bin', 'pip') if sys.platform != 'win32' else os.path.join(venv_path, 'Scripts', 'pip')
            install_dependencies(pip_executable)

            # Re-invoke the script using the virtual environment's Python executable
            python_executable = os.path.join(venv_path, 'bin', 'python') if sys.platform != 'win32' else os.path.join(venv_path, 'Scripts', 'python.exe')
            logging.info("Re-invoking script inside virtual environment...")
            subprocess.run([python_executable, *sys.argv, '--venv-activated'], check=True)

        except Exception as e:
            logging.error(f"An error occurred during setup: {str(e)}")
            raise
        finally:
            cleanup_venv(venv_path)
        sys.exit(0)

    # The script is now running inside the virtual environment
    from dotenv import load_dotenv

    # Load environment variables from .env if it exists
    if os.path.exists('.env'):
        load_dotenv()

    # Get domain name
    last_domain = get_last_domain()
    domain_name = os.getenv('DOMAIN_NAME') or input(f"Enter the domain name (last used: {last_domain}): ") or last_domain
    if not domain_name:
        raise ValueError("Domain name must be provided.")
    save_last_domain(domain_name)

    # Sanitize domain name to create repo name
    repo_name = sanitize_domain_name(domain_name)

    # Get color theme
    colors = ["red", "orange", "yellow", "green", "blue", "indigo", "violet"]
    print("Choose a primary color theme (ROYGBIV):")
    for idx, c in enumerate(colors, start=1):
        print(f"{idx}. {c}")
    color_choice = int(input("Enter the number of your choice: ")) - 1
    if color_choice not in range(len(colors)):
        raise ValueError("Invalid color choice.")
    color = colors[color_choice]

    # Set environment variables for downstream scripts
    os.environ['DOMAIN_NAME'] = domain_name
    os.environ['REPO_NAME'] = repo_name
    os.environ['COLOR_THEME'] = color

    # Create GitHub repository
    create_github_repo(repo_name)
    
    # Clone the template repository and set up remotes
    template_repo_url = 'git@github.com:l3ocifer/aws-s3-cdn-acm-website.git'  # Template repo SSH URL
    setup_local_repo(repo_name, template_repo_url)
    
    # Change to the newly created repository directory
    repo_path = os.path.join(os.path.expanduser('~/git/websites'), repo_name)
    os.chdir(repo_path)
    
    logging.info("Starting main setup process...")
    # Add the current directory and the scripts directory to Python path
    sys.path.append(os.getcwd())
    scripts_dir = os.path.join(os.getcwd(), 'scripts')
    sys.path.append(scripts_dir)
    # Set PYTHONPATH environment variable
    os.environ['PYTHONPATH'] = f"{scripts_dir}:{os.environ.get('PYTHONPATH', '')}"
    # Run main script using the virtual environment's Python executable
    venv_python = sys.executable
    subprocess.run([venv_python, '-m', 'scripts.main'], check=True, env=os.environ)
    
    logging.info(f"Website setup complete for {domain_name}")

if __name__ == '__main__':
    main()
