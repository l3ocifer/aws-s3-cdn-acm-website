#!/bin/bash
set -euo pipefail

handle_content_file() {
    if [ ! -f .content ]; then
        echo "No .content file found. Please choose an option:"
        echo "1. Enter content manually"
        echo "2. Provide path to content file"
        echo "3. Skip (use default content)"
        read -p "Enter your choice (1-3): " content_choice

        case $content_choice in
            1)
                read -p "Enter your business description: " business_description
                read -p "Enter your contact info: " contact_info
                echo -e "$business_description\n\nContact Info:\n$contact_info" > .content
                ;;
            2)
                read -p "Enter the path to your content file: " content_file_path
                [ -f "$content_file_path" ] && cp "$content_file_path" .content || error "Content file not found at $content_file_path"
                ;;
            3)
                echo "Hello World! This is $DOMAIN_NAME" > .content
                ;;
            *)
                error "Invalid choice. Please run the script again and select a valid option."
                ;;
        esac
    fi

    jq -n --arg content "$(cat .content)" '[{"title": "Welcome", "content": $content}]' > react/src/content.json
}

setup_react_app() {
    if [ ! -d "react" ]; then
        npx create-react-app react --template minimal || error "Failed to create React app"
    fi

    cat << EOF > react/src/App.js
import React from 'react';
import './App.css';
import content from './content.json';

function App() {
    return (
        <div className="App">
            <h1>Welcome to ${DOMAIN_NAME}</h1>
            <div className="content">
                {content.map((item, index) => (
                    <div key={index}>
                        <h2>{item.title}</h2>
                        <p>{item.content}</p>
                    </div>
                ))}
            </div>
        </div>
    );
}

export default App;
EOF

    cat << EOF > react/src/App.css
.App {
    text-align: center;
    font-family: Arial, sans-serif;
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
}

.content {
    text-align: left;
}
EOF

    handle_content_file

    (cd react && npm run build) || error "Failed to build React app"
}

setup_react_app
