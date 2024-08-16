#!/usr/bin/env bash

set -euo pipefail

setup_terraform_vars() {
    DOMAIN_NAME=$(cat .domain)
    REPO_NAME=$(echo "$DOMAIN_NAME" | sed -E 's/\.[^.]+$//')
    HOSTED_ZONE_ID=$(cat .hosted_zone_id)
    ACM_CERT_EXISTS=$(cat .acm_cert_exists)

    cat << EOF > terraform/terraform.tfvars
domain_name = "${DOMAIN_NAME}"
repo_name = "${REPO_NAME}"
hosted_zone_id = "${HOSTED_ZONE_ID}"
acm_cert_exists = ${ACM_CERT_EXISTS}
EOF
}

setup_backend_bucket() {
    local bucket_name="${REPO_NAME}-tf-state"

    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        echo "Creating backend S3 bucket: $bucket_name"
        aws s3api create-bucket --bucket "$bucket_name" --region us-east-1
        aws s3api put-bucket-versioning --bucket "$bucket_name" --versioning-configuration Status=Enabled
        aws s3api put-bucket-encryption --bucket "$bucket_name" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
    else
        echo "Backend S3 bucket already exists: $bucket_name"
    fi
}

import_hosted_zone() {
    if [ ! -f .hosted_zone_id ]; then
        echo "Error: .hosted_zone_id file not found. Running create_or_get_hosted_zone again."
        source ./scripts/setup_aws.sh
        create_or_get_hosted_zone
    fi
    
    HOSTED_ZONE_ID=$(cat .hosted_zone_id)
    DOMAIN_NAME=$(cat .domain)
    
    if [ -z "$HOSTED_ZONE_ID" ]; then
        echo "Error: Hosted zone ID is empty. Please check the .hosted_zone_id file."
        exit 1
    fi
    
    echo "Importing hosted zone ${HOSTED_ZONE_ID} for ${DOMAIN_NAME} into Terraform state"
    terraform import aws_route53_zone.main "${HOSTED_ZONE_ID}" || {
        echo "Failed to import hosted zone. It may already be in the Terraform state."
    }
}

init_apply_terraform() {
    (
        cd terraform
        terraform init
        import_hosted_zone
        terraform apply -auto-approve
    )
}

setup_terraform_vars
setup_backend_bucket
init_apply_terraform