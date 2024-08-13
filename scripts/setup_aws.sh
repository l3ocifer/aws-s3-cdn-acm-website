#!/usr/bin/env bash

set -euo pipefail

# Function to check and setup AWS credentials
setup_aws_credentials() {
    if [ -z "${AWS_PROFILE:-}" ]; then
        if [ -f .env ]; then
            source .env
        fi
        if [ -z "${AWS_PROFILE:-}" ]; then
            echo "WARNING: AWS_PROFILE is not set. Using default profile." >&2
            AWS_PROFILE=default
        fi
    fi
    export AWS_PROFILE

    if ! aws sts get-caller-identity &> /dev/null; then
        echo "AWS credentials not configured. Running 'aws configure'..." >&2
        aws configure || { echo "Failed to configure AWS credentials." >&2; exit 1; }
        echo "AWS_PROFILE=${AWS_PROFILE}" > .env
    fi
}

# Function to check AWS CLI version
check_aws_cli_version() {
    local min_version="2.0.0"
    local current_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    if [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" != "$min_version" ]; then
        echo "ERROR: AWS CLI version $current_version is less than the required version $min_version" >&2
        exit 1
    fi
}

# Function to check if hosted zone exists
check_hosted_zone() {
    DOMAIN_NAME=$(cat .domain)
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${DOMAIN_NAME}." --query "HostedZones[?Name == '${DOMAIN_NAME}.'].Id" --output text)
    if [[ -n "$HOSTED_ZONE_ID" ]]; then
        echo "Hosted zone for ${DOMAIN_NAME} already exists."
        HOSTED_ZONE_EXISTS=true
    else
        echo "No hosted zone found for ${DOMAIN_NAME}. It will be created."
        HOSTED_ZONE_EXISTS=false
    fi
    export HOSTED_ZONE_EXISTS
}

# Function to check if ACM certificate exists
check_acm_certificate() {
    DOMAIN_NAME=$(cat .domain)
    ACM_CERT_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName=='${DOMAIN_NAME}'].CertificateArn" --output text)
    if [[ -n "$ACM_CERT_ARN" ]]; then
        echo "ACM certificate for ${DOMAIN_NAME} already exists."
        ACM_CERT_EXISTS=true
    else
        echo "No ACM certificate found for ${DOMAIN_NAME}. It will be created."
        ACM_CERT_EXISTS=false
    fi
    export ACM_CERT_EXISTS
}

# Cleanup function
cleanup() {
    echo "Cleaning up AWS setup..."
    rm -f .env
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
check_aws_cli_version
setup_aws_credentials
check_hosted_zone
check_acm_certificate
