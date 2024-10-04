Website Creation Automation
This project automates the setup of a static website hosted on AWS using Terraform and Next.js. It sets up AWS infrastructure, initializes a Next.js app, customizes it, and deploys it to AWS S3 and CloudFront.

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
- Generate an .env file with environment variables
- Set up AWS infrastructure using Terraform
- Initialize and customize a Next.js app
- Deploy the website to AWS

## Environment Variables

You can set the following environment variables before running the script:

- `GITHUB_USERNAME`: Your GitHub username
- `GITHUB_ACCESS_TOKEN`: Your GitHub personal access token
- `DOMAIN_NAME`: The domain name for your website
- `AWS_PROFILE` (optional): The AWS CLI profile to use (default is 'default')

If these are not set, the script will prompt you for the necessary information.

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

