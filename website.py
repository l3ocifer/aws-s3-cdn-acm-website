import os
import subprocess
import json
import time
import boto3
import requests
from botocore.exceptions import ClientError
from PIL import Image, ImageDraw, ImageFont
import openai

# Set up OpenAI API key
openai.api_key = os.getenv('OPENAI_API_KEY')

def run(cmd):
    return subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True).stdout.strip()

def setup_aws():
    if 'AWS_PROFILE' not in os.environ:
        os.environ['AWS_PROFILE'] = 'default' if not os.path.exists('.env') else next((line.split('=')[1].strip() for line in open('.env') if line.startswith('AWS_PROFILE=')), 'default')
    try:
        run('aws sts get-caller-identity')
    except:
        run('aws configure')
        open('.env', 'w').write(f"AWS_PROFILE={os.environ['AWS_PROFILE']}")
    if run('aws --version').split('/')[1].split(' ')[0] < "2.0.0":
        raise Exception("AWS CLI version must be >= 2.0.0")

def create_or_update_s3_website(domain_name):
    repo_name = domain_name.replace(".", "-")
    s3, cf, r53, acm = (boto3.client(s) for s in ('s3', 'cloudfront', 'route53', 'acm'))

    # Check if S3 bucket exists, create if not
    try:
        s3.head_bucket(Bucket=repo_name)
    except ClientError:
        s3.create_bucket(Bucket=repo_name)
        s3.put_bucket_website(Bucket=repo_name, WebsiteConfiguration={'IndexDocument': {'Suffix': 'index.html'}, 'ErrorDocument': {'Key': 'error.html'}})

    # Check if CloudFront distribution exists, create or update if necessary
    existing_dist = next((dist for dist in cf.list_distributions()['DistributionList']['Items'] if domain_name in dist['Aliases'].get('Items', [])), None)

    if existing_dist:
        dist_id, dist_domain = existing_dist['Id'], existing_dist['DomainName']
        oai_id = existing_dist['Origins']['Items'][0]['S3OriginConfig']['OriginAccessIdentity'].split('/')[-1]
    else:
        oai = cf.create_cloud_front_origin_access_identity(CloudFrontOriginAccessIdentityConfig={'CallerReference': str(time.time()), 'Comment': 'OAI for S3 website'})
        oai_id = oai['CloudFrontOriginAccessIdentity']['Id']

        dist_config = {
            'CallerReference': str(time.time()),
            'Aliases': {'Quantity': 1, 'Items': [domain_name]},
            'DefaultRootObject': 'index.html',
            'Origins': {'Quantity': 1, 'Items': [{'Id': 'S3-Origin', 'DomainName': f'{repo_name}.s3.amazonaws.com', 'S3OriginConfig': {'OriginAccessIdentity': f'origin-access-identity/cloudfront/{oai_id}'}}]},
            'DefaultCacheBehavior': {
                'TargetOriginId': 'S3-Origin',
                'ViewerProtocolPolicy': 'redirect-to-https',
                'AllowedMethods': {'Quantity': 3, 'Items': ['HEAD', 'GET', 'OPTIONS']},
                'CachedMethods': {'Quantity': 2, 'Items': ['HEAD', 'GET']},
                'ForwardedValues': {'QueryString': False, 'Cookies': {'Forward': 'none'}},
                'MinTTL': 0, 'DefaultTTL': 3600, 'MaxTTL': 86400,
                'Compress': True
            },
            'Enabled': True,
            'Comment': 'S3 website distribution',
            'PriceClass': 'PriceClass_100',
            'HttpVersion': 'http2',
            'ViewerCertificate': {
                'CloudFrontDefaultCertificate': True
            }
        }
        dist = cf.create_distribution(DistributionConfig=dist_config)
        dist_id, dist_domain = dist['Distribution']['Id'], dist['Distribution']['DomainName']

    # Update S3 bucket policy
    account_id = boto3.client('sts').get_caller_identity().get('Account')
    s3.put_bucket_policy(Bucket=repo_name, Policy=json.dumps({
        'Version': '2012-10-17',
        'Statement': [{
            'Sid': 'AllowCloudFrontAccess',
            'Effect': 'Allow',
            'Principal': {'Service': 'cloudfront.amazonaws.com'},
            'Action': 's3:GetObject',
            'Resource': f'arn:aws:s3:::{repo_name}/*',
            'Condition': {'StringEquals': {'AWS:SourceArn': f'arn:aws:cloudfront::{account_id}:distribution/{dist_id}'}}
        }]
    }))

    # Set up or update Route 53
    zone = next((z for z in r53.list_hosted_zones_by_name()['HostedZones'] if z['Name'] == f'{domain_name}.'), None)
    if not zone:
        zone = r53.create_hosted_zone(Name=domain_name, CallerReference=str(time.time()))
        zone_id = zone['HostedZone']['Id']
        
        # Get the nameservers for the new hosted zone
        nameservers = zone['DelegationSet']['NameServers']
        
        # Update the domain's nameservers
        domain = r53.get_domain(DomainName=domain_name)
        r53.update_domain_nameservers(
            DomainName=domain_name,
            Nameservers=[{'Name': ns} for ns in nameservers]
        )
        print(f"Updated nameservers for {domain_name}: {', '.join(nameservers)}")
    else:
        zone_id = zone['Id']

    r53.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch={'Changes': [{'Action': 'UPSERT', 'ResourceRecordSet': {'Name': domain_name, 'Type': 'A', 'AliasTarget': {'HostedZoneId': 'Z2FDTNDATAQYW2', 'DNSName': dist_domain, 'EvaluateTargetHealth': False}}}]}
    )

    # Set up or update ACM certificate
    existing_cert = next((cert for cert in acm.list_certificates()['CertificateSummaryList'] if cert['DomainName'] == domain_name), None)
    if existing_cert:
        cert_arn = existing_cert['CertificateArn']
    else:
        cert = acm.request_certificate(DomainName=domain_name, ValidationMethod='DNS')
        cert_arn = cert['CertificateArn']
        
        # Wait for the certificate to be issued and add DNS validation record
        while True:
            cert_details = acm.describe_certificate(CertificateArn=cert_arn)
            if 'DomainValidationOptions' in cert_details['Certificate']:
                for option in cert_details['Certificate']['DomainValidationOptions']:
                    if 'ResourceRecord' in option:
                        r53.change_resource_record_sets(
                            HostedZoneId=zone_id,
                            ChangeBatch={
                                'Changes': [{
                                    'Action': 'UPSERT',
                                    'ResourceRecordSet': {
                                        'Name': option['ResourceRecord']['Name'],
                                        'Type': option['ResourceRecord']['Type'],
                                        'TTL': 300,
                                        'ResourceRecords': [{'Value': option['ResourceRecord']['Value']}]
                                    }
                                }]
                            }
                        )
                        break
                break
            time.sleep(5)
        
        acm.get_waiter('certificate_validated').wait(CertificateArn=cert_arn)

    # Update CloudFront distribution with the certificate
    cf.update_distribution(
        Id=dist_id,
        DistributionConfig={**cf.get_distribution(Id=dist_id)['Distribution']['DistributionConfig'],
                            'ViewerCertificate': {'AcmCertificateArn': cert_arn, 'SslSupportMethod': 'sni-only', 'MinimumProtocolVersion': 'TLSv1.2_2021'}}
    )

    return {'website_url': f'https://{domain_name}', 'cloudfront_distribution_id': dist_id}

# ... [rest of the code remains the same] ...

def main():
    setup_aws()
    config = load_or_create_config()

    if 'domain_name' in config:
        use_existing = input(f"Use existing domain '{config['domain_name']}'? (y/n): ").lower() == 'y'
        if not use_existing:
            del config['domain_name']
            del config['description']

    if 'domain_name' not in config:
        config['domain_name'] = input("Enter the domain name for your website: ")
        config['description'] = input("Enter a brief description of your website (1-3 sentences): ")
        save_config(config)

    domain_name = config['domain_name']
    description = config['description']
    repo_name = domain_name.replace('.', '-')

    print("Setting up S3 and CloudFront...")
    website_info = create_or_update_s3_website(domain_name)

    print("Setting up Next.js application...")
    setup_nextjs(domain_name, description)

    print("Building the website...")
    os.chdir('next-app')
    run('npm run build')
    os.chdir('..')

    print("Deploying the website...")
    deploy_website(domain_name, repo_name)

    print(f"Deployment complete! Your website should be accessible at {website_info['website_url']}")
    print("Please allow some time for the DNS changes to propagate.")

if __name__ == "__main__":
    main()