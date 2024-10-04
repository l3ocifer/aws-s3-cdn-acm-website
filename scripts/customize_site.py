# File: scripts/customize_site.py

import os
import logging
import hashlib

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def generate_color_palette(domain_name):
    """Generate a color palette based on the domain name."""
    hash_object = hashlib.md5(domain_name.encode())
    hex_dig = hash_object.hexdigest()
    
    primary = f"#{hex_dig[:6]}"
    secondary = f"#{hex_dig[6:12]}"
    accent = f"#{hex_dig[12:18]}"
    
    return primary, secondary, accent

def update_globals_css(app_dir, primary, secondary, accent):
    """Update globals.css with Tailwind base styles and custom global styles."""
    globals_css_path = os.path.join(app_dir, 'src', 'app', 'globals.css')
    logging.info(f"Updating {globals_css_path} with Tailwind base styles and custom styles.")

    globals_css_content = f"""
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {{
  --primary: {primary};
  --secondary: {secondary};
  --accent: {accent};
}}

body {{
  @apply bg-gray-50 text-gray-800;
}}

.prose {{
  @apply max-w-none;
}}

.btn-primary {{
  @apply bg-primary text-white px-6 py-2 rounded hover:bg-opacity-90 transition-colors;
}}

.nav-link {{
  @apply hover:text-accent transition-colors;
}}
"""
    with open(globals_css_path, 'w') as f:
        f.write(globals_css_content)
    logging.info("globals.css updated successfully.")

def update_layout_tsx(app_dir, domain_name):
    """Update layout.tsx to include Header and Footer with navigation links."""
    layout_tsx_path = os.path.join(app_dir, 'src', 'app', 'layout.tsx')
    logging.info(f"Updating {layout_tsx_path} with Header and Footer.")

    layout_content = f"""import './globals.css'
import type {{ Metadata }} from "next";
import Link from 'next/link';

export const metadata: Metadata = {{
  title: "{domain_name}",
  description: "Welcome to {domain_name}. Discover our offerings and services.",
}};

export default function RootLayout({{
  children,
}}: {{
  children: React.ReactNode;
}}) {{
  return (
    <html lang="en">
      <body className="flex flex-col min-h-screen">
        <header className="bg-primary text-white">
          <div className="container mx-auto flex justify-between items-center p-4">
            <h1 className="text-2xl font-bold">{domain_name}</h1>
            <nav>
              <ul className="flex space-x-6">
                <li><Link href="/" className="nav-link">Home</Link></li>
                <li><Link href="/about" className="nav-link">About</Link></li>
                <li><Link href="/services" className="nav-link">Services</Link></li>
                <li><Link href="/contact" className="nav-link">Contact</Link></li>
              </ul>
            </nav>
          </div>
        </header>
        <main className="flex-grow container mx-auto px-4 py-8">
          {{children}}
        </main>
        <footer className="bg-secondary text-white">
          <div className="container mx-auto text-center p-4">
            &copy; {{new Date().getFullYear()}} {domain_name}. All rights reserved.
          </div>
        </footer>
      </body>
    </html>
  );
}}
"""
    with open(layout_tsx_path, 'w') as f:
        f.write(layout_content)
    logging.info("layout.tsx updated successfully.")

def update_page_tsx(app_dir, domain_name):
    """Update page.tsx with a hero section and services overview."""
    page_tsx_path = os.path.join(app_dir, 'src', 'app', 'page.tsx')
    logging.info(f"Updating {page_tsx_path} with enhanced Home page content.")

    home_page_content = f"""import Link from 'next/link';

export default function Home() {{
  return (
    <div className="space-y-12">
      <section className="text-center">
        <h1 className="text-4xl font-bold mb-4">Welcome to {domain_name}</h1>
        <p className="text-xl mb-8">Elevating standards, delivering excellence.</p>
        <Link href="/about" className="btn-primary">Learn More</Link>
      </section>
      <section className="grid md:grid-cols-3 gap-8">
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h2 className="text-xl font-semibold mb-4">Innovative Solutions</h2>
          <p>Cutting-edge approaches to meet your unique needs.</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h2 className="text-xl font-semibold mb-4">Expert Team</h2>
          <p>Dedicated specialists committed to your success.</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h2 className="text-xl font-semibold mb-4">Quality Assurance</h2>
          <p>Rigorous standards ensuring top-tier results.</p>
        </div>
      </section>
    </div>
  )
}}
"""
    with open(page_tsx_path, 'w') as f:
        f.write(home_page_content)
    logging.info("Home page content updated successfully.")

def create_about_page(app_dir, domain_name):
    """Create about/page.tsx with generic content."""
    about_dir = os.path.join(app_dir, 'src', 'app', 'about')
    os.makedirs(about_dir, exist_ok=True)
    about_page_path = os.path.join(about_dir, 'page.tsx')
    logging.info(f"Creating About page at {about_page_path}.")

    about_content = f"""export default function About() {{
  return (
    <div className="prose max-w-none">
      <h1 className="text-3xl font-bold mb-6">About Us</h1>
      <p className="mb-4">
        At {domain_name}, we are dedicated to delivering exceptional solutions that meet and exceed expectations. 
        Our team of experts brings a wealth of experience and innovative thinking to every project.
      </p>
      <p className="mb-4">
        With a focus on quality and client satisfaction, we strive to build lasting relationships 
        and contribute to the success of our clients across various industries.
      </p>
      <h2 className="text-2xl font-semibold mt-8 mb-4">Our Approach</h2>
      <ul className="list-disc pl-6 mb-4">
        <li>Thorough understanding of client needs</li>
        <li>Tailored solutions for optimal results</li>
        <li>Continuous improvement and adaptation</li>
        <li>Commitment to excellence in every aspect</li>
      </ul>
    </div>
  )
}}
"""
    with open(about_page_path, 'w') as f:
        f.write(about_content)
    logging.info("About page created successfully.")

def create_services_page(app_dir):
    """Create services/page.tsx with generic content."""
    services_dir = os.path.join(app_dir, 'src', 'app', 'services')
    os.makedirs(services_dir, exist_ok=True)
    services_page_path = os.path.join(services_dir, 'page.tsx')
    logging.info(f"Creating Services page at {services_page_path}.")

    services_content = """export default function Services() {
  return (
    <div className="prose max-w-none">
      <h1 className="text-3xl font-bold mb-6">Our Services</h1>
      <p className="mb-8">We offer a comprehensive range of services designed to meet your needs:</p>
      <div className="grid md:grid-cols-2 gap-8">
        <div>
          <h2 className="text-2xl font-semibold mb-4">Strategic Consulting</h2>
          <p>Expert guidance to help you navigate complex challenges and achieve your goals.</p>
        </div>
        <div>
          <h2 className="text-2xl font-semibold mb-4">Custom Solutions</h2>
          <p>Tailored approaches developed to address your specific requirements and objectives.</p>
        </div>
        <div>
          <h2 className="text-2xl font-semibold mb-4">Implementation Support</h2>
          <p>Comprehensive assistance to ensure smooth execution and optimal results.</p>
        </div>
        <div>
          <h2 className="text-2xl font-semibold mb-4">Ongoing Optimization</h2>
          <p>Continuous improvement strategies to enhance performance and drive long-term success.</p>
        </div>
      </div>
    </div>
  )
}
"""
    with open(services_page_path, 'w') as f:
        f.write(services_content)
    logging.info("Services page created successfully.")

def create_contact_page(app_dir, domain_name):
    """Create contact/page.tsx with a contact form that opens the default email client."""
    contact_dir = os.path.join(app_dir, 'src', 'app', 'contact')
    os.makedirs(contact_dir, exist_ok=True)
    contact_page_path = os.path.join(contact_dir, 'page.tsx')
    logging.info(f"Creating Contact page at {contact_page_path}.")

    contact_content = f"""'use client';

import {{ useState }} from 'react';

export default function Contact() {{
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');

  const handleSubmit = (e: React.FormEvent) => {{
    e.preventDefault();
    const subject = encodeURIComponent('New Inquiry from ' + name);
    const body = encodeURIComponent(`Name: ${{name}}\\nEmail: ${{email}}\\nMessage: ${{message}}`);
    window.location.href = `mailto:admin@{domain_name}?subject=${{subject}}&body=${{body}}`;
  }};

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Contact Us</h1>
      <p className="mb-8">We value your inquiries and feedback. Please reach out to us using the form below:</p>
      <form className="space-y-4" onSubmit={{handleSubmit}}>
        <div>
          <label htmlFor="name" className="block text-sm font-medium mb-1">Name</label>
          <input 
            type="text" 
            id="name" 
            name="name" 
            value={{name}}
            onChange={{(e) => setName(e.target.value)}}
            className="w-full px-3 py-2 border border-gray-300 rounded-md" 
            required 
          />
        </div>
        <div>
          <label htmlFor="email" className="block text-sm font-medium mb-1">Email</label>
          <input 
            type="email" 
            id="email" 
            name="email" 
            value={{email}}
            onChange={{(e) => setEmail(e.target.value)}}
            className="w-full px-3 py-2 border border-gray-300 rounded-md" 
            required 
          />
        </div>
        <div>
          <label htmlFor="message" className="block text-sm font-medium mb-1">Message</label>
          <textarea 
            id="message" 
            name="message" 
            value={{message}}
            onChange={{(e) => setMessage(e.target.value)}}
            rows={{4}} 
            className="w-full px-3 py-2 border border-gray-300 rounded-md" 
            required
          ></textarea>
        </div>
        <button type="submit" className="btn-primary">Send Message</button>
      </form>
    </div>
  );
}}
"""
    with open(contact_page_path, 'w') as f:
        f.write(contact_content)
    logging.info("Contact page created successfully.")

def update_tailwind_config(app_dir):
    """Update tailwind.config.ts with custom theme configuration."""
    tailwind_config_path = os.path.join(app_dir, 'tailwind.config.ts')
    logging.info(f"Updating {tailwind_config_path} with custom theme configuration.")

    tailwind_config_content = """import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: "var(--primary)",
        secondary: "var(--secondary)",
        accent: "var(--accent)",
      },
    },
  },
  plugins: [],
};
export default config;
"""
    with open(tailwind_config_path, 'w') as f:
        f.write(tailwind_config_content)
    logging.info("tailwind.config.ts updated successfully.")

def update_next_config(app_dir):
    """Update next.config.js with custom configuration."""
    next_config_path = os.path.join(app_dir, 'next.config.js')
    logging.info(f"Updating {next_config_path} with custom configuration.")

    next_config_content = """/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
}

module.exports = nextConfig
"""
    with open(next_config_path, 'w') as f:
        f.write(next_config_content)
    logging.info("next.config.js updated successfully.")

def customize_site(domain_name):
    """Main function to customize the Next.js site."""
    app_dir = 'next-app'

    if not os.path.exists(app_dir):
        logging.error(f"Directory '{app_dir}' does not exist. Ensure that the Next.js app is initialized.")
        return

    primary, secondary, accent = generate_color_palette(domain_name)

    update_globals_css(app_dir, primary, secondary, accent)
    update_layout_tsx(app_dir, domain_name)
    update_page_tsx(app_dir, domain_name)
    create_about_page(app_dir, domain_name)
    create_services_page(app_dir)
    create_contact_page(app_dir, domain_name)
    update_tailwind_config(app_dir)
    update_next_config(app_dir)

    logging.info("Site customization complete!")

if __name__ == '__main__':
    import sys
    if len(sys.argv) != 2:
        print("Usage: python customize_site.py <domain_name>")
        sys.exit(1)
    try:
        customize_site(sys.argv[1])
    except Exception as e:
        logging.error(f"An error occurred during site customization: {str(e)}")
        raise