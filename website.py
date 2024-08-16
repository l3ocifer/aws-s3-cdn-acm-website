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
        acm.get_waiter('certificate_validated').wait(CertificateArn=cert_arn)

    # Update CloudFront distribution with the certificate
    cf.update_distribution(
        Id=dist_id,
        DistributionConfig={**cf.get_distribution(Id=dist_id)['Distribution']['DistributionConfig'],
                            'ViewerCertificate': {'AcmCertificateArn': cert_arn, 'SslSupportMethod': 'sni-only', 'MinimumProtocolVersion': 'TLSv1.2_2021'}}
    )

    return {'website_url': f'https://{domain_name}', 'cloudfront_distribution_id': dist_id}

def generate_content(description):
    response = openai.Completion.create(
        engine="text-davinci-002",
        prompt=f"Create a short welcome message and content for a website about: {description}",
        max_tokens=150
    )
    return response.choices[0].text.strip()

def generate_logo(description):
    response = openai.Image.create(
        prompt=f"A simple logo for: {description}",
        n=1,
        size="256x256"
    )
    image_url = response['data'][0]['url']
    image_data = requests.get(image_url).content
    with open('logo.png', 'wb') as f:
        f.write(image_data)
    return 'logo.png'

def setup_nextjs(domain_name, description):
    if not os.path.exists('next-app'):
        run('npx create-next-app@latest next-app --typescript --eslint --use-npm --tailwind --src-dir --app --import-alias "@/*" --no-git --yes')
    os.chdir('next-app')

    # Update package.json
    with open('package.json', 'r+') as f:
        data = json.load(f)
        data['scripts']['build'] = "next build"
        f.seek(0)
        json.dump(data, f, indent=2)
        f.truncate()

    # Create next.config.mjs
    open('next.config.mjs', 'w').write('export default {output:"export",distDir:"../public",images:{unoptimized:true}};')

    # Generate content
    content = generate_content(description)
    open('../.content', 'w').write(content)

    # Generate logo
    logo_path = generate_logo(description)
    open('../.logo', 'w').write(logo_path)

    # Set up content and layout
    os.makedirs('src', exist_ok=True)
    json.dump([{"title": "Welcome", "content": content}], open('src/content.json', 'w'))

    # Create layout.tsx
    open('src/app/layout.tsx', 'w').write(f"""
import './globals.css';
import {{ Inter }} from 'next/font/google';
const inter = Inter({{subsets:['latin']}});
export const metadata = {{title:'{domain_name}',description:'{description}'}};
export default function RootLayout({{children}}:{{children:React.ReactNode}}) {{
  return (
    <html lang="en">
      <body className={{inter.className}}>{{children}}</body>
    </html>
  );
}};
    """.strip())

    # Create page.tsx
    open('src/app/page.tsx', 'w').write(f"""
import Image from 'next/image';
import content from '../content.json';
export default function Home() {{
  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div className="z-10 w-full max-w-5xl items-center justify-between font-mono text-sm lg:flex">
        <p className="fixed left-0 top-0 flex w-full justify-center border-b border-gray-300 bg-gradient-to-b from-zinc-200 pb-6 pt-8 backdrop-blur-2xl dark:border-neutral-800 dark:bg-zinc-800/30 dark:from-inherit lg:static lg:w-auto lg:rounded-xl lg:border lg:bg-gray-200 lg:p-4 lg:dark:bg-zinc-800/30 lg:dark:border-neutral-800">
          Welcome to&nbsp;<code className="font-mono font-bold">{domain_name}</code>
        </p>
        <div className="fixed bottom-0 left-0 flex h-48 w-full items-end justify-center bg-gradient-to-t from-white via-white dark:from-black dark:via-black lg:static lg:h-auto lg:w-auto lg:bg-none">
          <Image src="/logo.png" alt="{domain_name} Logo" className="dark:invert" width={{100}} height={{24}} priority/>
        </div>
      </div>
      <div className="relative flex place-items-center">
        <h1 className="text-4xl font-bold">Welcome to {domain_name}</h1>
      </div>
      <div className="mb-32 grid text-center lg:max-w-5xl lg:w-full lg:mb-0 lg:grid-cols-4 lg:text-left">
        <div className="group rounded-lg border border-transparent px-5 py-4 transition-colors hover:border-gray-300 hover:bg-gray-100 hover:dark:border-neutral-700 hover:dark:bg-neutral-800/30">
          <h2 className="mb-3 text-2xl font-semibold">Welcome</h2>
          <p className="m-0 max-w-[30ch] text-sm opacity-50">{{content[0].content}}</p>
        </div>
      </div>
    </main>
  );
}};
    """.strip())

    # Set up public directory and logo
    os.makedirs('public', exist_ok=True)
    os.replace('../logo.png', 'public/logo.png')
    run('npm install')
    os.chdir('..')

def deploy_website(domain_name, repo_name):
    if not os.path.exists('public'):
        raise Exception("'public' directory not found. Make sure the website has been built.")
    s3 = boto3.client('s3')
    for obj in s3.list_objects_v2(Bucket=repo_name).get('Contents', []):
        s3.delete_object(Bucket=repo_name, Key=obj['Key'])
    for root, _, files in os.walk('public'):
        for file in files:
            file_path = os.path.join(root, file)
            key = os.path.relpath(file_path, 'public')
            extra_args = {'CacheControl': 'max-age=31536000,public,immutable'} if not file.endswith('.html') else {'CacheControl': 'no-cache'}
            s3.upload_file(file_path, repo_name, key, ExtraArgs=extra_args)
    cf = boto3.client('cloudfront')
    for dist in cf.list_distributions()['DistributionList']['Items']:
        if domain_name in dist['Aliases'].get('Items', []):
            cf.create_invalidation(DistributionId=dist['Id'], InvalidationBatch={'Paths': {'Quantity': 1, 'Items': ['/*']}, 'CallerReference': str(int(time.time()))})
            break
def load_or_create_config():
    config_file = os.path.expanduser('~/.website_config.json')
    if os.path.exists(config_file):
        with open(config_file, 'r') as f:
            return json.load(f)
    return {}

def save_config(config):
    config_file = os.path.expanduser('~/.website_config.json')
    with open(config_file, 'w') as f:
        json.dump(config, f)

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
