#!/usr/bin/env bash

set -euo pipefail

check_aws_cli_version() {
    local min_version="2.0.0"
    local current_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    if [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" != "$min_version" ]; then
        echo "ERROR: AWS CLI version $current_version is less than the required version $min_version" >&2
        exit 1
    fi
}

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

get_registered_nameservers() {
    local domain_name="$1"
    aws route53domains get-domain-detail --domain-name "$domain_name" \
        --query 'Nameservers[].Name' --output text | tr '\t' '\n' | sort
}

get_hosted_zone_nameservers() {
    local hosted_zone_id="$1"
    aws route53 get-hosted-zone --id "$hosted_zone_id" \
        --query 'DelegationSet.NameServers' --output text | tr '\t' '\n' | sort
}

check_pending_operations() {
    local domain_name="$1"
    local pending_ops=$(aws route53domains list-operations --status IN_PROGRESS --query "Operations[?DomainName=='$domain_name'].OperationId" --output text)
    if [[ -n "$pending_ops" ]]; then
        echo "Pending operations found for $domain_name. Waiting for completion..."
        aws route53domains wait operation-success --operation-id $pending_ops
        echo "Pending operations completed."
    fi
}

update_registered_nameservers() {
    local domain_name="$1"
    local hosted_zone_id="$2"
    local hosted_zone_ns=($(get_hosted_zone_nameservers "$hosted_zone_id"))
    local max_retries=5
    local retry_delay=30

    local nameservers_json="["
    for ns in "${hosted_zone_ns[@]}"; do
        nameservers_json+="{\"Name\":\"$ns\"},"
    done
    nameservers_json="${nameservers_json%,}]"

    for ((i=1; i<=max_retries; i++)); do
        check_pending_operations "$domain_name"
        if aws route53domains update-domain-nameservers \
            --domain-name "$domain_name" \
            --nameservers "$nameservers_json"; then
            echo "Updated registered nameservers for $domain_name"
            return 0
        else
            echo "Failed to update nameservers. Retrying in $retry_delay seconds... (Attempt $i of $max_retries)"
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))
        fi
    done

    echo "Failed to update nameservers after $max_retries attempts."
    return 1
}

create_or_get_hosted_zone() {
    DOMAIN_NAME=$(cat .domain)
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${DOMAIN_NAME}." --query "HostedZones[?Name == '${DOMAIN_NAME}.'].Id" --output text | sed 's/^\/hostedzone\///')
    
    if [[ -z "$HOSTED_ZONE_ID" ]]; then
        echo "No hosted zone found for ${DOMAIN_NAME}. Creating a new one."
        HOSTED_ZONE_ID=$(aws route53 create-hosted-zone --name "${DOMAIN_NAME}" --caller-reference "$(date +%s)" --query "HostedZone.Id" --output text | sed 's/^\/hostedzone\///')
        echo "Created new hosted zone with ID: ${HOSTED_ZONE_ID}"
    else
        echo "Existing hosted zone found for ${DOMAIN_NAME} with ID: ${HOSTED_ZONE_ID}"
    fi

    echo "${HOSTED_ZONE_ID}" > .hosted_zone_id
    echo "Hosted zone ID saved to .hosted_zone_id file"

    # Compare and update nameservers if necessary
    local registered_ns=($(get_registered_nameservers "$DOMAIN_NAME"))
    local hosted_zone_ns=($(get_hosted_zone_nameservers "$HOSTED_ZONE_ID"))

    if [[ "${registered_ns[*]}" != "${hosted_zone_ns[*]}" ]]; then
        echo "Nameservers mismatch detected. Updating registered nameservers..."
        update_registered_nameservers "$DOMAIN_NAME" "$HOSTED_ZONE_ID"
    else
        echo "Nameservers are already in sync."
    fi
}

check_acm_certificate() {
    DOMAIN_NAME=$(cat .domain)
    ACM_CERT_ARN=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" --output text)
    if [ -n "$ACM_CERT_ARN" ]; then
        echo "ACM certificate for $DOMAIN_NAME already exists."
        echo "true" > .acm_cert_exists
    else
        echo "ACM certificate for $DOMAIN_NAME does not exist."
        echo "false" > .acm_cert_exists
    fi
}

# Main execution
check_aws_cli_version
setup_aws_credentials
create_or_get_hosted_zone
check_acm_certificate