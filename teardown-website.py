#!/usr/bin/env python3

import os
import subprocess
import shutil
import sys
import venv
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def create_venv():
    venv_path = 'teardown_venv'
    try:
        venv.create(venv_path, with_pip=True)
        return venv_path
    except Exception as e:
        logging.error(f"Failed to create virtual environment: {e}")
        return None

def install_requirements(venv_path):
    if not venv_path:
        return
    pip_path = os.path.join(venv_path, 'bin', 'pip')
    try:
        subprocess.run([pip_path, 'install', 'boto3'], check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to install requirements: {e}")

def run_in_venv(venv_path):
    if not venv_path:
        return
    python_path = os.path.join(venv_path, 'bin', 'python')
    try:
        subprocess.run([python_path, __file__, '--in-venv'], check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to run script in virtual environment: {e}")

def cleanup_venv(venv_path):
    if venv_path and os.path.exists(venv_path):
        try:
            shutil.rmtree(venv_path)
        except Exception as e:
            logging.error(f"Failed to remove virtual environment: {e}")

def run_command(command):
    try:
        subprocess.run(command, shell=True, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed: {e}")

def setup_venv():
    logging.info("Setting up virtual environment...")
    run_command("python3 -m venv teardown_venv")
    activate_venv()

def activate_venv():
    activate_script = os.path.join("teardown_venv", "bin", "activate_this.py")
    if os.path.exists(activate_script):
        with open(activate_script) as file_:
            exec(file_.read(), dict(__file__=activate_script))
    else:
        logging.error(f"Activation script not found: {activate_script}")

def remove_venv():
    logging.info("Removing virtual environment...")
    cleanup_venv("teardown_venv")

def terraform_destroy():
    logging.info("Running Terraform destroy...")
    try:
        os.chdir("terraform")
        run_command("terraform init")
        run_command("terraform destroy -auto-approve")
    except Exception as e:
        logging.error(f"Failed to run Terraform destroy: {e}")
    finally:
        os.chdir("..")

def empty_and_remove_s3_buckets():
    print("Emptying and removing S3 buckets...")
    import boto3
    s3 = boto3.resource('s3')
    
    tf_state_bucket_name = get_terraform_variable('tf_state_bucket_name')
    website_bucket_name = get_terraform_variable('website_bucket_name')
    
    for bucket_name in [tf_state_bucket_name, website_bucket_name]:
        if not bucket_name:
            print(f"Error: {bucket_name} not found in Terraform outputs")
            continue

        bucket = s3.Bucket(bucket_name)
        bucket.objects.all().delete()
        bucket.delete()

def delete_github_repo():
    print("Deleting GitHub repository...")
    repo_name = get_terraform_variable('repo_name')
    
    if not repo_name:
        print("Error: repo_name not found in Terraform outputs")
        return

    run_command(f"gh repo delete {repo_name} --yes")

def delete_local_repo():
    print("Deleting local repository...")
    current_dir = os.getcwd()
    parent_dir = os.path.dirname(current_dir)
    os.chdir(parent_dir)
    shutil.rmtree(current_dir)

def get_terraform_variable(var_name):
    try:
        output = subprocess.check_output(['terraform', 'output', '-raw', var_name], cwd='terraform')
        return output.decode('utf-8').strip()
    except subprocess.CalledProcessError:
        return None

def main():
    try:
        setup_venv()
        terraform_destroy()
        empty_and_remove_s3_buckets()
        delete_github_repo()
        logging.info("Teardown complete. This script will now exit.")
    except Exception as e:
        logging.error(f"An error occurred: {e}")
    finally:
        remove_venv()
        logging.info("Virtual environment removed.")

def run_teardown():
    current_dir = os.getcwd()
    parent_dir = os.path.dirname(current_dir)
    try:
        main()
    finally:
        logging.info("Deleting local repository...")
        os.chdir(parent_dir)
        try:
            shutil.rmtree(current_dir)
        except Exception as e:
            logging.error(f"Failed to delete local repository: {e}")

if __name__ == "__main__":
    if '--in-venv' not in sys.argv:
        venv_path = create_venv()
        if venv_path:
            try:
                install_requirements(venv_path)
                run_in_venv(venv_path)
            finally:
                cleanup_venv(venv_path)
    else:
        run_teardown()