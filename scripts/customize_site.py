# File: scripts/customize_site.py

import os
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)

def customize_site(domain_name):
    """Customize the Next.js app based on user input."""
    app_dir = 'next-app'
    config_file = os.path.join(app_dir, 'tailwind.config.js')
    page_file = os.path.join(app_dir, 'src', 'app', 'page.tsx')

    if not os.path.exists(config_file) or not os.path.exists(page_file):
        logging.error("Tailwind config or page.tsx not found.")
        return

    # Prompt for color theme
    colors = ["yellow", "violet", "orange", "blue", "red", "indigo", "green"]
    print("Choose a primary color theme:")
    for idx, color in enumerate(colors, start=1):
        print(f"{idx}. {color}")
    color_choice = int(input("Enter the number of your choice: ")) - 1
    if color_choice not in range(len(colors)):
        logging.error("Invalid color choice.")
        return
    color = colors[color_choice]

    # Update tailwind.config.js
    with open(config_file, 'r') as f:
        config_content = f.read()

    # Modify the extend section with the selected color
    if 'extend: {}' in config_content:
        config_content = config_content.replace('extend: {}', f"""extend: {{
    colors: {{
      primary: '{color}',
    }},
  }}""")

    with open(config_file, 'w') as f:
        f.write(config_content)
    logging.info("Updated tailwind.config.js with selected theme.")

    # Update page.tsx
    with open(page_file, 'r') as f:
        page_content = f.read()

    # Replace text-gray-900 with text-primary
    page_content = page_content.replace('text-gray-900', 'text-primary')

    with open(page_file, 'w') as f:
        f.write(page_content)
    logging.info("Updated page.tsx with selected color theme.")

    logging.info("Site customization complete!")

if __name__ == '__main__':
    domain_name = os.getenv('DOMAIN_NAME')
    if not domain_name:
        domain_name = input("Enter the domain name: ")
        os.environ['DOMAIN_NAME'] = domain_name
    customize_site(domain_name)
