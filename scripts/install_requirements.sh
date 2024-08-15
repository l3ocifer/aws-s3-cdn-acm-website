#!/usr/bin/env bash

set -euo pipefail

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install required tools
install_requirements() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    for cmd in aws terraform npm npx jq git node sharp; do
        if ! command_exists $cmd; then
            case $cmd in
                aws)
                    curl "https://awscli.amazonaws.com/awscli-exe-${os}-${arch}.zip" -o "awscliv2.zip"
                    unzip awscliv2.zip
                    sudo ./aws/install --update
                    rm -rf aws awscliv2.zip
                    ;;
                terraform)
                    local tf_version="1.5.7"
                    curl "https://releases.hashicorp.com/terraform/${tf_version}/terraform_${tf_version}_${os}_amd64.zip" -o terraform.zip
                    unzip terraform.zip
                    sudo mv terraform /usr/local/bin/
                    rm terraform.zip
                    ;;
                npm|npx|node)
                    if command_exists apt-get; then
                        sudo apt-get update
                        sudo apt-get install -y nodejs npm
                    elif command_exists brew; then
                        brew install node
                    else
                        echo "Please install Node.js and npm manually and run this script again." >&2
                        exit 1
                    fi
                    ;;
                jq|git)
                    if command_exists apt-get; then
                        sudo apt-get update
                        sudo apt-get install -y $cmd
                    elif command_exists brew; then
                        brew install $cmd
                    else
                        echo "Please install $cmd manually and run this script again." >&2
                        exit 1
                    fi
                    ;;
                sharp)
                    npm install -g sharp-cli --yes
                    ;;
            esac
        fi
    done
}

install_requirements
