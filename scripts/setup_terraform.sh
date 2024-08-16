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

init_apply_terraform() {
    (
        cd terraform
        terraform init -reconfigure -input=false
        terraform import aws_route53_zone.primary $(cat ../.hosted_zone_id) || true
        terraform plan -out=tfplan
        terraform apply -auto-approve tfplan
    )
}

setup_terraform_vars
setup_backend_bucket
init_apply_terraform