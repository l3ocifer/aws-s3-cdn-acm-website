import os, subprocess, json, time, boto3, requests, anthropic, shutil, mimetypes
from botocore.exceptions import ClientError
from PIL import Image, ImageDraw, ImageFont
import argparse
import logging
from botocore.exceptions import WaiterError
from anthropic import Anthropic, HUMAN_PROMPT, AI_PROMPT

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def run(cmd): return subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True).stdout.strip()

def setup_aws():
    if 'AWS_PROFILE' not in os.environ:
        os.environ['AWS_PROFILE'] = 'default' if not os.path.exists('.env') else next((line.split('=')[1].strip() for line in open('.env') if line.startswith('AWS_PROFILE=')), 'default')
    try: run('aws sts get-caller-identity')
    except: run('aws configure'); open('.env', 'w').write(f"AWS_PROFILE={os.environ['AWS_PROFILE']}")
    if run('aws --version').split('/')[1].split(' ')[0] < "2.0.0": raise Exception("AWS CLI version must be >= 2.0.0")

def create_or_update_s3_website(domain_name):
    repo_name = domain_name.replace(".", "-")
    s3, cf, r53, acm = (boto3.client(s) for s in ('s3', 'cloudfront', 'route53', 'acm'))

    # Create S3 bucket if it doesn't exist
    try:
        s3.head_bucket(Bucket=repo_name)
    except ClientError:
        s3.create_bucket(Bucket=repo_name)

    s3.put_bucket_website(Bucket=repo_name, WebsiteConfiguration={'IndexDocument': {'Suffix': 'index.html'}, 'ErrorDocument': {'Key': 'error.html'}})

    # Create or get OAC
    oacs = cf.list_cloud_front_origin_access_controls()['CloudFrontOriginAccessControlList']['Items']
    oac = next((o for o in oacs if o['Description'] == f'OAC for {repo_name}'), None)
    if not oac:
        oac = cf.create_cloud_front_origin_access_control(CloudFrontOriginAccessControlConfig={'Description': f'OAC for {repo_name}'})['CloudFrontOriginAccessControl']
    oac_id = oac['Id']

    s3.put_bucket_policy(Bucket=repo_name, Policy=json.dumps({
        'Version': '2012-10-17',
        'Statement': [{
            'Sid': 'AllowCloudFrontAccess',
            'Effect': 'Allow',
            'Principal': {'CanonicalUser': oac['S3CanonicalUserId']},
            'Action': 's3:GetObject',
            'Resource': f'arn:aws:s3:::{repo_name}/*'
        }]
    }))

    # Create or update CloudFront distribution
    distributions = cf.list_distributions()['DistributionList']['Items']
    dist = next((d for d in distributions if domain_name in d['Aliases']['Items']), None)
    dist_config = {
        'CallerReference': str(time.time()),
        'Aliases': {'Quantity': 1, 'Items': [domain_name]},
        'DefaultRootObject': 'index.html',
        'Origins': {'Quantity': 1, 'Items': [{'Id': 'S3-Origin', 'DomainName': f'{repo_name}.s3.amazonaws.com', 'S3OriginConfig': {'OriginAccessControlId': oac_id}}]},
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
        'Comment': f'S3 website distribution for {domain_name}',
        'PriceClass': 'PriceClass_100',
        'HttpVersion': 'http2',
        'ViewerCertificate': {
            'CloudFrontDefaultCertificate': True
        }
    }
    if dist:
        dist = cf.update_distribution(Id=dist['Id'], DistributionConfig=dist_config)['Distribution']
    else:
        dist = cf.create_distribution(DistributionConfig=dist_config)['Distribution']
    dist_id, dist_domain = dist['Id'], dist['DomainName']

   # Create or update Route53 record and handle nameserver updates
    zone = create_or_get_hosted_zone(domain_name)
    update_route53_record(zone['Id'], domain_name, dist_domain)
    handle_nameserver_updates(zone, domain_name)

    # Create or get ACM certificate
    certs = acm.list_certificates()['CertificateSummaryList']
    cert = next((c for c in certs if c['DomainName'] == domain_name), None)
    if not cert:
        try:
            cert = acm.request_certificate(DomainName=domain_name, ValidationMethod='DNS')
            waiter = acm.get_waiter('certificate_validated')
            waiter.wait(
                CertificateArn=cert['CertificateArn'],
                WaiterConfig={'Delay': 30, 'MaxAttempts': 60}
            )
            time.sleep(10)  # Allow time for the certificate to propagate
        except WaiterError:
            logger.error(f"ACM certificate validation timed out for {domain_name}")
            return None
        except ClientError as e:
            logger.error(f"Error requesting ACM certificate: {e}")
            return None

    # Update CloudFront distribution with ACM certificate
    cf.update_distribution(
        Id=dist_id,
        DistributionConfig={**dist_config, 'ViewerCertificate': {'AcmCertificateArn': cert['CertificateArn'], 'SslSupportMethod': 'sni-only', 'MinimumProtocolVersion': 'TLSv1.2_2021'}}
    )

    return {'website_url': f'https://{domain_name}', 'cloudfront_distribution_id': dist_id}

def create_or_get_hosted_zone(domain_name):
    r53 = boto3.client('route53')
    zones = r53.list_hosted_zones_by_name(DNSName=domain_name)['HostedZones']
    zone = next((z for z in zones if z['Name'] == f'{domain_name}.'), None)
    if not zone:
        logger.info(f"Creating new hosted zone for {domain_name}")
        zone = r53.create_hosted_zone(Name=domain_name, CallerReference=str(time.time()))['HostedZone']
    return zone

def update_route53_record(zone_id, domain_name, dist_domain):
    r53 = boto3.client('route53')
    try:
        r53.change_resource_record_sets(
            HostedZoneId=zone_id,
            ChangeBatch={
                'Changes': [{
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': domain_name,
                        'Type': 'A',
                        'AliasTarget': {
                            'HostedZoneId': 'Z2FDTNDATAQYW2',
                            'DNSName': dist_domain,
                            'EvaluateTargetHealth': False
                        }
                    }
                }]
            }
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'Throttling':
            logger.warning("Rate limit hit. Waiting before retry...")
            time.sleep(5)  # Wait for 5 seconds before retrying
            update_route53_record(zone_id, domain_name, dist_domain)
        else:
            raise

def handle_nameserver_updates(zone, domain_name):
    r53 = boto3.client('route53')
    r53domains = boto3.client('route53domains')

    # Get the nameservers for the hosted zone
    zone_nameservers = r53.get_hosted_zone(Id=zone['Id'])['DelegationSet']['NameServers']

    try:
        # Get the current nameservers for the domain
        domain_nameservers = r53domains.get_domain_detail(DomainName=domain_name)['Nameservers']
        domain_nameservers = [ns['Name'].rstrip('.') for ns in domain_nameservers]
    except ClientError as e:
        if e.response['Error']['Code'] == 'UnsupportedTLD':
            logger.warning(f"Unable to automatically update nameservers for {domain_name}. Please update them manually.")
            logger.info(f"Nameservers for {domain_name}: {', '.join(zone_nameservers)}")
            return
        else:
            raise

    # Check if nameservers need to be updated
    if set(zone_nameservers) != set(domain_nameservers):
        logger.info(f"Updating nameservers for {domain_name}")
        try:
            r53domains.update_domain_nameservers(
                DomainName=domain_name,
                Nameservers=[{'Name': ns} for ns in zone_nameservers]
            )
            logger.info(f"Nameservers updated for {domain_name}")
        except ClientError as e:
            if e.response['Error']['Code'] == 'Throttling':
                logger.warning("Rate limit hit. Waiting before retry...")
                time.sleep(5)  # Wait for 5 seconds before retrying
                handle_nameserver_updates(zone, domain_name)
            else:
                raise
    else:
        logger.info(f"Nameservers for {domain_name} are already correct")

    # Always log the current nameservers
    logger.info(f"Current nameservers for {domain_name}: {', '.join(zone_nameservers)}")

def update_nameservers_route53(domain_name, nameservers):
    r53domains = boto3.client('route53domains')
    try:
        r53domains.update_domain_nameservers(
            DomainName=domain_name,
            Nameservers=[{'Name': ns} for ns in nameservers]
        )
        logger.info(f"Nameservers updated for {domain_name}")
    except ClientError as e:
        if e.response['Error']['Code'] == 'Throttling':
            logger.warning("Rate limit hit. Waiting before retry...")
            time.sleep(5)  # Wait for 5 seconds before retrying
            update_nameservers_route53(domain_name, nameservers)
        else:
            raise

def setup_nextjs(domain_name, description):
    if os.path.exists("next-app"):
        print("Next.js app already set up. Updating configuration...")
        os.chdir("next-app")
    else:
        print("Creating Next.js app...")
        run("npx create-next-app@latest next-app --typescript --eslint --use-npm --tailwind --src-dir --app --import-alias '@/*' --no-git --yes")
        os.chdir("next-app")

    # Update package.json scripts
    with open('package.json', 'r+') as f:
        package_json = json.load(f)
        package_json['scripts']['build'] = "next build"
        f.seek(0)
        json.dump(package_json, f, indent=2)
        f.truncate()

    # Update next.config.mjs
    next_config = f"""
/** @type {{import('next').NextConfig}} */
const nextConfig = {{
  output: 'export',
  distDir: '../public',
  images: {{
    unoptimized: true,
  }},
}};

export default nextConfig;
"""
    with open('next.config.mjs', 'w') as f:
        f.write(next_config)

    handle_content_file(domain_name)
    handle_logo_file()

    os.makedirs('src', exist_ok=True)
    with open('../.content', 'r') as f:
        content = f.read()
    with open('src/content.json', 'w') as f:
        json.dump([{"title": "Welcome", "content": content}], f)

    # Update src/app/layout.tsx
    layout_tsx = f"""
import './globals.css'
import {{ Inter }} from 'next/font/google'

const inter = Inter({{ subsets: ['latin'] }})

export const metadata = {{
  title: '{domain_name}',
  description: 'Welcome to {domain_name}',
}}

export default function RootLayout({{
  children,
}}: {{
  children: React.ReactNode
}}) {{
  return (
    <html lang="en">
      <body className={{inter.className}}>{{children}}</body>
    </html>
  )
}}
"""
    with open('src/app/layout.tsx', 'w') as f:
        f.write(layout_tsx)

    # Update src/app/page.tsx
    page_tsx = f"""
import Image from 'next/image'
import content from '../content.json'

export default function Home() {{
  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div className="z-10 w-full max-w-5xl items-center justify-between font-mono text-sm lg:flex">
        <p className="fixed left-0 top-0 flex w-full justify-center border-b border-gray-300 bg-gradient-to-b from-zinc-200 pb-6 pt-8 backdrop-blur-2xl dark:border-neutral-800 dark:bg-zinc-800/30 dark:from-inherit lg:static lg:w-auto lg:rounded-xl lg:border lg:bg-gray-200 lg:p-4 lg:dark:bg-zinc-800/30 lg:dark:border-neutral-800">
          Welcome to&nbsp;
          <code className="font-mono font-bold">{domain_name}</code>
        </p>
        <div className="fixed bottom-0 left-0 flex h-48 w-full items-end justify-center bg-gradient-to-t from-white via-white dark:from-black dark:via-black lg:static lg:h-auto lg:w-auto lg:bg-none">
          <a
            className="pointer-events-none flex place-items-center gap-2 p-8 lg:pointer-events-auto lg:p-0"
            href="https://{domain_name}"
            target="_blank"
            rel="noopener noreferrer"
          >
            By {{' '}}
            <Image
              src="/logo.png"
              alt="{domain_name} Logo"
              className="dark:invert"
              width={{100}}
              height={{24}}
              priority
            />
          </a>
        </div>
      </div>

      <div className="relative flex place-items-center before:absolute before:h-[300px] before:w-[480px] before:-translate-x-1/2 before:rounded-full before:bg-gradient-radial before:from-white before:to-transparent before:blur-2xl before:content-[''] after:absolute after:-z-20 after:h-[180px] after:w-[240px] after:translate-x-1/3 after:bg-gradient-conic after:from-sky-200 after:via-blue-200 after:blur-2xl after:content-[''] before:dark:bg-gradient-to-br before:dark:from-transparent before:dark:to-blue-700 before:dark:opacity-10 after:dark:from-sky-900 after:dark:via-[#0141ff] after:dark:opacity-40 before:lg:h-[360px]">
        <h1 className="text-4xl font-bold">Welcome to {domain_name}</h1>
      </div>

      <div className="mb-32 grid text-center lg:max-w-5xl lg:w-full lg:mb-0 lg:grid-cols-4 lg:text-left">
        <div className="group rounded-lg border border-transparent px-5 py-4 transition-colors hover:border-gray-300 hover:bg-gray-100 hover:dark:border-neutral-700 hover:dark:bg-neutral-800/30">
          <h2 className="mb-3 text-2xl font-semibold">
            Welcome
          </h2>
          <p className="m-0 max-w-[30ch] text-sm opacity-50">
            This is your new website. Start customizing it!
          </p>
        </div>
      </div>
    </main>
  )
}}
"""
    with open('src/app/page.tsx', 'w') as f:
        f.write(page_tsx)

    # Update favicon and other icons
    os.makedirs('public', exist_ok=True)
    with open('../.logo', 'r') as f:
        logo_path = f.read().strip()
    
    if logo_path != "default":
        if logo_path.startswith('http'):
            run(f"curl -o public/icon.png {logo_path}")
        else:
            shutil.copy(logo_path, "public/icon.png")
        
        try:
            run("npm install sharp")
            run("npx sharp -i public/icon.png -o public/favicon.ico --format ico")
            run("npx sharp -i public/icon.png -o public/logo.png resize 100 24")
            run("npx sharp -i public/icon.png -o public/apple-touch-icon.png resize 180 180")
            for size in [16, 32, 192, 512]:
                run(f"npx sharp -i public/icon.png -o public/icon-{size}x{size}.png resize {size} {size}")
        except subprocess.CalledProcessError:
            print("Error processing images with sharp. Using original image as is.")
    else:
        create_default_logo(domain_name, "public/logo.png")
        shutil.copy("public/logo.png", "public/icon.png")

    run("npm install")
    os.chdir("..")

def build_nextjs_app():
    original_dir = os.getcwd()
    try:
        os.chdir("next-app")
        run("npm run build")
    finally:
        os.chdir(original_dir)

def generate_ai_content(description):
    client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    prompt = f"{HUMAN_PROMPT}Generate a short, engaging website content for a business with the following description: {description}{AI_PROMPT}"
    
    try:
        response = client.completions.create(
            model="claude-2.1",
            prompt=prompt,
            max_tokens_to_sample=300,
            temperature=0.7,
        )
        return response.completion.strip()
    except Exception as e:
        print(f"Error generating content: {e}")
        return "An error occurred while generating content."

def generate_ai_logo(domain_name, description):
    api_key = os.getenv("DALL_E_API_KEY")
    url = "https://api.openai.com/v1/images/generations"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    data = {
        "prompt": f"Create a simple, modern logo for a website with the domain name {domain_name}. The business is about: {description}",
        "n": 1,
        "size": "256x256"
    }
    
    try:
        response = requests.post(url, headers=headers, json=data)
        response.raise_for_status()
        return response.json()['data'][0]['url']
    except Exception as e:
        print(f"Error generating logo: {e}")
        return None

def deploy_website(domain_name, repo_name):
    s3 = boto3.client('s3')
    cf = boto3.client('cloudfront')
    bucket_name = repo_name
    
    if not os.path.exists('public'):
        logger.error("Public directory not found. Make sure the Next.js build was successful.")
        return None

    try:
        for root, dirs, files in os.walk('public'):
            for file in files:
                local_path = os.path.join(root, file)
                relative_path = os.path.relpath(local_path, 'public')
                content_type = mimetypes.guess_type(local_path)[0] or 'application/octet-stream'
                s3.upload_file(
                    local_path, 
                    bucket_name, 
                    relative_path,
                    ExtraArgs={'ContentType': content_type}
                )
        
        try:
            # Get the CloudFront distribution ID
            distributions = cf.list_distributions()['DistributionList']['Items']
            dist = next((d for d in distributions if domain_name in d['Aliases']['Items']), None)
            if dist:
                cf.create_invalidation(
                    DistributionId=dist['Id'],
                    InvalidationBatch={
                        'Paths': {
                            'Quantity': 1,
                            'Items': ['/*']
                        },
                        'CallerReference': str(time.time())
                    }
                )
                logger.info("CloudFront cache invalidated")
        except Exception as e:
            logger.warning(f"Error invalidating CloudFront cache: {e}")

        logger.info(f"Website deployed to: https://{domain_name}")
        return f"https://{domain_name}"
    except Exception as e:
        logger.error(f"Error deploying website: {e}")
        return None

def destroy_infrastructure(domain_name):
    repo_name = domain_name.replace(".", "-")
    s3, cf, r53, acm = (boto3.client(s) for s in ('s3', 'cloudfront', 'route53', 'acm'))

    # Delete S3 bucket contents and bucket
    try:
        bucket = s3.list_objects_v2(Bucket=repo_name)
        if 'Contents' in bucket:
            for obj in bucket['Contents']:
                s3.delete_object(Bucket=repo_name, Key=obj['Key'])
        s3.delete_bucket(Bucket=repo_name)
    except ClientError as e:
        logger.warning(f"Error deleting S3 bucket: {e}")

    # Delete CloudFront distribution
    distributions = cf.list_distributions()['DistributionList']['Items']
    dist = next((d for d in distributions if domain_name in d['Aliases']['Items']), None)
    if dist:
        cf.delete_distribution(Id=dist['Id'], IfMatch=dist['ETag'])

    # Delete Route53 records and hosted zone
    zone = next((z for z in r53.list_hosted_zones_by_name(DNSName=domain_name)['HostedZones'] if z['Name'] == f'{domain_name}.'), None)
    if zone:
        records = r53.list_resource_record_sets(HostedZoneId=zone['Id'])['ResourceRecordSets']
        for record in records:
            if record['Type'] not in ['NS', 'SOA']:
                r53.change_resource_record_sets(
                    HostedZoneId=zone['Id'],
                    ChangeBatch={
                        'Changes': [{
                            'Action': 'DELETE',
                            'ResourceRecordSet': record
                        }]
                    }
                )
        r53.delete_hosted_zone(Id=zone['Id'])

    # Delete ACM certificate
    certs = acm.list_certificates()['CertificateSummaryList']
    cert = next((c for c in certs if c['DomainName'] == domain_name), None)
    if cert:
        acm.delete_certificate(CertificateArn=cert['CertificateArn'])

    logger.info(f"Infrastructure for {domain_name} has been destroyed.")

def handle_content_file(domain_name):
    if not os.path.exists('.content'):
        print("No .content file found. Creating a default one.")
        with open('.content', 'w') as f:
            f.write(f"Welcome to {domain_name}")

def handle_logo_file():
    if not os.path.exists('.logo'):
        print("No .logo file found. Using default logo.")
        with open('.logo', 'w') as f:
            f.write("default")

def create_default_logo(domain_name, output_file):
    try:
        img = Image.new('RGB', (100, 24), color='white')
        d = ImageDraw.Draw(img)
        fnt = ImageFont.truetype("arial.ttf", 12)
        d.text((10, 10), domain_name, font=fnt, fill='black')
        img.save(output_file)
    except Exception as e:
        print(f"Error creating logo: {e}. Created a text file as a placeholder logo.")
        with open(output_file, 'w') as f:
            f.write(domain_name)

def main():
    parser = argparse.ArgumentParser(description="S3 Website Creator and Manager")
    parser.add_argument('action', choices=['create', 'update', 'destroy'], help="Action to perform")
    parser.add_argument('--domain', required=True, help="Domain name for the website")
    parser.add_argument('--description', help="Short description of the website for AI-generated content")
    args = parser.parse_args()

    try:
        setup_aws()

        # Check if AWS credentials are valid
        try:
            boto3.client('sts').get_caller_identity()
        except Exception as e:
            logger.error(f"Invalid AWS credentials: {e}")
            return

        required_env_vars = ["ANTHROPIC_API_KEY", "DALL_E_API_KEY"]
        missing_vars = [var for var in required_env_vars if not os.getenv(var)]
        if missing_vars:
            logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
            return

        if args.action in ['create', 'update']:
            website_info = create_or_update_s3_website(args.domain)
            if website_info is None:
                logger.error("Failed to create or update S3 website.")
                return
            if args.description:
                content = generate_ai_content(args.description)
                logo_url = generate_ai_logo(args.domain, args.description)
                with open('.content', 'w') as f:
                    f.write(content)
                with open('.logo', 'w') as f:
                    f.write(logo_url if logo_url else "default")
                setup_nextjs(args.domain, args.description)
                build_nextjs_app()
            deploy_result = deploy_website(args.domain, args.domain.replace(".", "-"))
            if deploy_result:
                logger.info(f"Deployment complete! Your website should be accessible at {website_info['website_url']}")
                logger.info("Please allow some time for the DNS changes to propagate.")
            else:
                logger.error("Deployment failed.")
        elif args.action == 'destroy':
            destroy_infrastructure(args.domain)
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    main()