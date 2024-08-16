#!/usr/bin/env bash

set -euo pipefail

setup_terraform_vars() {
    DOMAIN_NAME=$(cat .domain)

    check_hosted_zone
    check_acm_certificate

    cat << EOF > terraform/terraform.tfvars
domain_name = "${DOMAIN_NAME}"
hosted_zone_exists = ${HOSTED_ZONE_EXISTS}
acm_cert_exists = ${ACM_CERT_EXISTS}
EOF
}

setup_backend_bucket() {
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

init_apply_terraform() {
    (
        cd terraform
        terraform init -reconfigure -input=false
        terraform plan -out=tfplan
        terraform apply -auto-approve tfplan
    )
}

check_hosted_zone() {
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${DOMAIN_NAME}." --query "HostedZones[?Name == '${DOMAIN_NAME}.'].Id" --output text)
    if [[ -n "$HOSTED_ZONE_ID" ]]; then
        echo "Hosted zone for ${DOMAIN_NAME} already exists."
        HOSTED_ZONE_EXISTS=true
    else
        echo "No hosted zone found for ${DOMAIN_NAME}. It will be created."
        HOSTED_ZONE_EXISTS=false
    fi
}

check_acm_certificate() {
    ACM_CERT_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName=='${DOMAIN_NAME}'].CertificateArn" --output text)
    if [[ -n "$ACM_CERT_ARN" ]]; then
        echo "ACM certificate for ${DOMAIN_NAME} already exists."
        ACM_CERT_EXISTS=true
    else
        echo "No ACM certificate found for ${DOMAIN_NAME}. It will be created."
        ACM_CERT_EXISTS=false
    fi
}

setup_terraform_vars
setup_backend_bucket
init_apply_terraform
