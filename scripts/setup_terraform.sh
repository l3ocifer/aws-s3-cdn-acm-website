#!/usr/bin/env bash

set -euo pipefail

# Function to setup Terraform variables
setup_terraform_vars() {
    if [ ! -f .domain ]; then
        echo "Domain file (.domain) not found. Please run the main script first." >&2
        exit 1
    fi
    DOMAIN_NAME=$(cat .domain)

    if [ -z "${HOSTED_ZONE_EXISTS:-}" ] || [ -z "${ACM_CERT_EXISTS:-}" ]; then
        echo "HOSTED_ZONE_EXISTS and ACM_CERT_EXISTS must be set in the environment." >&2
        exit 1
    fi

    cat << EOF > terraform/terraform.tfvars
domain_name = "${DOMAIN_NAME}"
hosted_zone_exists = ${HOSTED_ZONE_EXISTS}
acm_cert_exists = ${ACM_CERT_EXISTS}
EOF

    # Update backend.tf with the correct bucket name
    sed -i.bak "s/DOMAIN_NAME_PLACEHOLDER/${DOMAIN_NAME}/g" terraform/backend.tf
    rm -f terraform/backend.tf.bak
}

# Function to setup or verify the backend S3 bucket
setup_backend_bucket() {
    DOMAIN_NAME=$(cat .domain)
    local bucket_name="${DOMAIN_NAME}-tf-state"

    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        echo "Creating backend S3 bucket: $bucket_name"
        aws s3api create-bucket --bucket "$bucket_name" --region us-east-1
        aws s3api put-bucket-versioning --bucket "$bucket_name" --versioning-configuration Status=Enabled
        aws s3api put-bucket-encryption --bucket "$bucket_name" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
    else
        echo "Backend S3 bucket already exists: $bucket_name"
    fi
}

# Function to initialize and apply Terraform
init_apply_terraform() {
    (
        cd terraform
        terraform init -reconfigure -input=false
        terraform apply -auto-approve -var-file=terraform.tfvars
    )
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f terraform/terraform.tfvars
    rm -f terraform/backend.tf.bak
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
setup_terraform_vars
setup_backend_bucket
init_apply_terraform
