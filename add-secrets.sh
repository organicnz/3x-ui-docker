#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Repository name
REPO="organicnz/3x-ui-docker"

echo -e "${YELLOW}This script will add GitHub secrets for 3x-ui Docker deployment.${NC}"
echo -e "${YELLOW}Make sure you are authenticated with GitHub CLI before proceeding.${NC}"
echo

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI not found. Please install it first."
    echo "Visit: https://cli.github.com/manual/installation"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "You are not authenticated with GitHub CLI."
    echo "Please run 'gh auth login' first."
    exit 1
fi

# SSH Private Key
echo -e "${GREEN}Setting up SSH_PRIVATE_KEY secret${NC}"
read -p "Enter path to SSH private key [~/.ssh/id_ed25519]: " SSH_KEY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_ed25519}

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found at $SSH_KEY_PATH"
    exit 1
fi

gh secret set SSH_PRIVATE_KEY -f "$SSH_KEY_PATH" -R "$REPO"
echo "✅ SSH_PRIVATE_KEY secret added."

# Server IP
echo -e "\n${GREEN}Setting up SERVER_HOST secret${NC}"
read -p "Enter your server IP or hostname: " SERVER_IP

if [ -z "$SERVER_IP" ]; then
    echo "Server IP/hostname cannot be empty."
    exit 1
fi

gh secret set SERVER_HOST -b "$SERVER_IP" -R "$REPO"
echo "✅ SERVER_HOST secret added."

# Generate and add SSH Known Hosts
echo -e "\n${GREEN}Setting up SSH_KNOWN_HOSTS secret${NC}"
echo "Generating SSH known hosts from $SERVER_IP..."
ssh-keyscan "$SERVER_IP" > known_hosts.tmp

if [ ! -s known_hosts.tmp ]; then
    echo "Failed to generate known hosts. Please check your server IP."
    rm known_hosts.tmp
    exit 1
fi

gh secret set SSH_KNOWN_HOSTS -f known_hosts.tmp -R "$REPO"
rm known_hosts.tmp
echo "✅ SSH_KNOWN_HOSTS secret added."

# SSH Username
echo -e "\n${GREEN}Setting up SERVER_USER secret${NC}"
read -p "Enter your SSH username: " SSH_USER

if [ -z "$SSH_USER" ]; then
    echo "SSH username cannot be empty."
    exit 1
fi

gh secret set SERVER_USER -b "$SSH_USER" -R "$REPO"
echo "✅ SERVER_USER secret added."

# Deployment path
echo -e "\n${GREEN}Setting up DEPLOY_PATH secret${NC}"
read -p "Enter the deployment path on your server [/home/$SSH_USER/3x-ui-docker]: " DEPLOY_PATH
DEPLOY_PATH=${DEPLOY_PATH:-/home/$SSH_USER/3x-ui-docker}

gh secret set DEPLOY_PATH -b "$DEPLOY_PATH" -R "$REPO"
echo "✅ DEPLOY_PATH secret added."

echo -e "\n${GREEN}All secrets have been added successfully!${NC}"
echo "You can now run the GitHub Actions workflow." 