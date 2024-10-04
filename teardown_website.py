import os
import subprocess
import boto3
import shutil
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def run_command(command):
    subprocess.run(command, shell=True, check=True)

def terraform_destroy():
    print("Running Terraform destroy...")
    os.chdir("terraform")
    run_command("terraform init")
    run_command("terraform destroy -auto-approve")
    os.chdir("..")

def empty_and_remove_s3_buckets():
    print("Emptying and removing S3 buckets...")
    s3 = boto3.resource('s3')
    
    tf_state_bucket_name = os.environ.get('TF_VAR_tf_state_bucket_name')
    website_bucket_name = os.environ.get('TF_VAR_website_bucket_name')
    
    for bucket_name in [tf_state_bucket_name, website_bucket_name]:
        if not bucket_name:
            print(f"Error: {bucket_name} environment variable not set")
            continue

        bucket = s3.Bucket(bucket_name)
        bucket.objects.all().delete()
        bucket.delete()

def delete_github_repo():
    print("Deleting GitHub repository...")
    repo_name = os.environ.get('TF_VAR_repo_name')
    
    if not repo_name:
        print("Error: TF_VAR_repo_name environment variable not set")
        return

    run_command(f"gh repo delete {repo_name} --yes")

def delete_local_repo():
    print("Deleting local repository...")
    current_dir = os.getcwd()
    parent_dir = os.path.dirname(current_dir)
    os.chdir(parent_dir)
    shutil.rmtree(current_dir)

def main():
    terraform_destroy()
    empty_and_remove_s3_buckets()
    delete_github_repo()
    delete_local_repo()
    print("Teardown complete. This script will now exit.")

if __name__ == "__main__":
    main()