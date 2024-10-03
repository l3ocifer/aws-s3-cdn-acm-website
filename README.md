Website Creation Automation
This project automates the setup of a static website hosted on AWS using Terraform and Next.js. It sets up AWS infrastructure, initializes a Next.js app, customizes it, and deploys it to AWS S3 and CloudFront.

Prerequisites
GitHub Account: Ensure you have a GitHub account with a personal access token (PAT) that has repo scope.
AWS Account: An AWS account with access configured via AWS CLI.
Domain Name: A domain name registered in AWS Route53.
SSH Keys: SSH keys configured for GitHub access.
Environment Variables
Before running the script, set the following environment variables:

GITHUB_USERNAME: Your GitHub username.
GITHUB_TOKEN: Your GitHub personal access token.
AWS_PROFILE (optional): The AWS CLI profile to use (default is default).
You can set these in your shell or in a .env file in the root directory (the .env file is generated automatically during the setup).

Steps to Run
Clone or Download the Repository

Clone this repository or download the code to your local machine.

bash
Copy code
git clone git@github.com:l3ocifer/website.git
cd website
Run the createwebsite.py Script

bash
Copy code
python createwebsite.py
Follow the Prompts

Enter the Domain Name: When prompted, enter the domain name registered in AWS Route53.

The script will:

Sanitize the domain name to create a repository name.
Create a new private GitHub repository in your account.
Clone the template repository and set up remotes.
Generate an .env file with environment variables.
Set up AWS infrastructure using Terraform.
Initialize and customize a Next.js app.
Deploy the website to AWS.
Customize the Website

During the setup, you will be prompted to select a color theme and mode for your website.
The Next.js app will be customized based on your selections.
Access Your Website

Once the script completes, your website should be accessible at https://yourdomain.com.
DNS propagation may take some time.
Notes
SSH Authentication: The script uses SSH for Git operations. Ensure your SSH keys are set up and added to your GitHub account.
AWS Configuration: Make sure your AWS CLI is configured (aws configure) and you have the necessary permissions.
Environment Variables: Sensitive information like GITHUB_TOKEN should be handled securely and not committed to version control.
State Information: The .env file stores environment variables and can be expanded to include state information as needed.
Troubleshooting
GitHub Authentication Errors: Ensure your SSH keys are correctly configured and your GITHUB_TOKEN is valid.
AWS Permission Errors: Verify that your AWS credentials have the necessary permissions for the services used.
Dependency Issues: Make sure all required tools are installed (Python, Git, AWS CLI, Terraform, Node.js).
License
This project is licensed under the MIT License.

