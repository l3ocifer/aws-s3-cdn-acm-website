Website Creation Automation
This project automates the setup of a static website hosted on AWS using Terraform and Next.js. It sets up a git repo at ~/git/websites/<your-new-repo>, downloads this template and sets it as an upstream remote, sets up an s3 backend using python, and uses terraform to build AWS infrastructure including a s3 bucket for the website, OAC & Cloudfront distro, and route53 records; then it initializes a Next.js app, customizes it, and deploys it to AWS S3 and CloudFront.

## Prerequisites

- Python 3.6 or higher
- pip (Python package installer)
- Git
- AWS CLI
- Terraform
- Node.js and npm

The script will automatically create a virtual environment and install the required Python packages (requests and python-dotenv) if they are not already installed.

## Running the Script

1. Download the `createwebsite.py` script.

2. Run the script:

   ```bash
   python createwebsite.py
   ```

3. Follow the prompts:
   - Enter the domain name (must be registered in AWS Route53)
   - Enter your GitHub username and access token (if not set as environment variables)

The script will:

- Sanitize the domain name to create a repository name
- Create a new private GitHub repository in your account
- Clone the template repository and set up remotes
- Set up AWS infrastructure using Terraform
- Initialize and customize a Next.js app
- Deploy the website to AWS

## Environment Variables

The following Terraform variables are used:

- `domain_name`: The domain name for your website
- `repo_name`: The name of the GitHub repository
- `tf_state_bucket_name`: The name of the S3 bucket for Terraform state
- `website_bucket_name`: The name of the S3 bucket for the website

These variables are managed through Terraform and do not need to be set as environment variables.

## Notes

- SSH Authentication: The script uses SSH for Git operations. Ensure your SSH keys are set up and added to your GitHub account.
- AWS Configuration: Make sure your AWS CLI is configured (`aws configure`) and you have the necessary permissions.
- Environment Variables: Sensitive information like `GITHUB_ACCESS_TOKEN` should be handled securely and not committed to version control.
- Virtual Environment: The script creates a temporary virtual environment for its execution and cleans it up afterwards, regardless of success or failure.

## Troubleshooting

- GitHub Authentication Errors: Ensure your SSH keys are correctly configured and your GitHub access token is valid.
- AWS Permission Errors: Verify that your AWS credentials have the necessary permissions for the services used.
- Dependency Issues: Make sure all required tools are installed (Python, Git, AWS CLI, Terraform, Node.js).

## License

This project is licensed under the Leo Paska License.

## Teardown Process

To completely remove the website and all associated resources, use the `teardown_website.py` script - it mostly works...

## Updating the Website

After making changes to your Next.js app, you can update the deployed website using the `update_site.sh` script:

1. Make sure you're in the root directory of your website project.

2. Run the update script:

   ```bash
   ./update_site.sh
   ```

This script will:
- Build the Next.js app
- Sync the built files to the S3 bucket
- Invalidate the CloudFront distribution cache

Make sure you have the necessary AWS credentials configured before running the update script.
