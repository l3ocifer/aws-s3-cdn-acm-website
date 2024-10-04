# File: scripts/install_requirements.py

import sys
import subprocess
import shutil
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)

def install_python_packages():
    """Install required Python packages using pip."""
    required_packages = [
        'boto3',
        'requests',
        'python-dotenv'
    ]
    for package in required_packages:
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])

def check_and_install_aws_cli():
    """Check if AWS CLI is installed; if not, install it."""
    if not shutil.which('aws'):
        logging.info("AWS CLI not found. Installing AWS CLI...")
        # Install AWS CLI v2
        subprocess.check_call(['curl', 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip', '-o', 'awscliv2.zip'])
        subprocess.check_call(['unzip', 'awscliv2.zip'])
        subprocess.check_call(['sudo', './aws/install'])
    else:
        logging.info("AWS CLI is already installed.")

def check_and_install_terraform():
    """Check if Terraform is installed; if not, install it."""
    if not shutil.which('terraform'):
        logging.info("Terraform not found. Installing Terraform...")
        # Install Terraform
        terraform_version = '1.5.7'
        subprocess.check_call(['wget', f'https://releases.hashicorp.com/terraform/{terraform_version}/terraform_{terraform_version}_linux_amd64.zip', '-O', 'terraform.zip'])
        subprocess.check_call(['unzip', 'terraform.zip'])
        subprocess.check_call(['sudo', 'mv', 'terraform', '/usr/local/bin/'])
    else:
        logging.info("Terraform is already installed.")

def check_and_install_node():
    """Check if Node.js and npm are installed; if not, install them."""
    if not shutil.which('node') or not shutil.which('npm'):
        logging.info("Node.js or npm not found. Installing Node.js and npm...")
        # Install Node.js (LTS version)
        subprocess.check_call(['curl', '-fsSL', 'https://deb.nodesource.com/setup_lts.x', '|', 'sudo', '-E', 'bash', '-'])
        subprocess.check_call(['sudo', 'apt-get', 'install', '-y', 'nodejs'])
    else:
        logging.info("Node.js and npm are already installed.")

def install_requirements():
    """Install all required tools and packages."""
    install_python_packages()
    check_and_install_aws_cli()
    check_and_install_terraform()
    check_and_install_node()
    logging.info("All requirements are installed.")

if __name__ == '__main__':
    install_requirements()
