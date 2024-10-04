# File: scripts/customize_site.py

import os
import logging
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def customize_site(domain_name):
    """Customize the Next.js app based on user input."""
    app_dir = 'next-app'
    page_file = os.path.join(app_dir, 'src', 'app', 'page.tsx')
    layout_file = os.path.join(app_dir, 'src', 'app', 'layout.tsx')

    if not os.path.exists(page_file) or not os.path.exists(layout_file):
        logging.error("page.tsx or layout.tsx not found.")
        return

    color = os.getenv('COLOR_THEME')
    if not color:
        logging.error("COLOR_THEME environment variable is not set.")
        return

    # Update page.tsx
    with open(page_file, 'w') as f:
        f.write(f"""
import styles from './page.module.css'

export default function Home() {{
  return (
    <main className={{styles.main}}>
      <h1 className={{styles.title}}>Welcome to {domain_name}</h1>
    </main>
  )
}}
""")

    # Create page.module.css
    css_file = os.path.join(app_dir, 'src', 'app', 'page.module.css')
    with open(css_file, 'w') as f:
        f.write(f"""
.main {{
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background-color: white;
}}

.title {{
  font-size: 3rem;
  color: {color};
  text-align: center;
}}
""")

    # Update layout.tsx to include the CSS
    with open(layout_file, 'r') as f:
        content = f.read()

    if "import './globals.css'" in content:
        content = content.replace("import './globals.css'", "import './globals.css'\nimport './page.module.css'")
    else:
        content = "import './page.module.css'\n" + content

    with open(layout_file, 'w') as f:
        f.write(content)

    logging.info("Site customization complete!")

if __name__ == '__main__':
    domain_name = os.getenv('DOMAIN_NAME')
    if not domain_name:
        raise ValueError("DOMAIN_NAME environment variable is not set.")
    customize_site(domain_name)
