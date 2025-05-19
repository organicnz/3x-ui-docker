#!/bin/bash

# Source utility functions and color variables
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
else
  echo -e "\033[0;31mError: utils.sh not found. Please ensure it exists in the scripts directory.\033[0m"
  exit 1
fi

echo -e "${BLUE}==== 3x-ui VPN CI/CD Configuration Sync ====${NC}"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}GitHub CLI (gh) is not installed. Please install it first:${NC}"
    echo -e "macOS: ${YELLOW}brew install gh${NC}"
    echo -e "Linux: ${YELLOW}https://github.com/cli/cli/blob/trunk/docs/install_linux.md${NC}"
    exit 1
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}You need to login to GitHub CLI first${NC}"
    gh auth login
fi

# Get repository name
REPO_URL=$(git config --get remote.origin.url)
if [ -z "$REPO_URL" ]; then
    echo -e "${RED}Unable to detect GitHub repository.${NC}"
    echo -e "${YELLOW}Please enter your GitHub repository in format 'owner/repo':${NC}"
    read REPO
else
    # Extract owner/repo from git URL
    if [[ $REPO_URL == *"github.com"* ]]; then
        REPO=$(echo $REPO_URL | sed -n 's/.*github.com[:/]\(.*\)\.git.*/\1/p')
        if [ -z "$REPO" ]; then
            REPO=$(echo $REPO_URL | sed -n 's/.*github.com[:/]\(.*\).*/\1/p')
        fi
    fi
    
    if [ -z "$REPO" ]; then
        echo -e "${RED}Unable to parse repository from git URL:${NC} $REPO_URL"
        echo -e "${YELLOW}Please enter your GitHub repository in format 'owner/repo':${NC}"
        read REPO
    fi
fi

echo -e "${BLUE}Working with repository:${NC} $REPO"

# Create environment variables for CI/CD
echo -e "${BLUE}Creating environment variables for CI/CD...${NC}"

# Create a .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file with default values...${NC}"
    cat > .env << EOL
# 3x-ui VPN Service Configuration

# Panel Access Settings
XUI_USERNAME=organic
XUI_PASSWORD=kjwegfwkeyyRDHJKH123
PANEL_PATH=BXv8SI7gBe

# Network Configuration
HTTPS_PORT=2053
VPN_DOMAIN=service.foodshare.club
ADMIN_EMAIL=tamerlanium@gmail.com

# XRay Configuration
XRAY_VMESS_AEAD_FORCED=false

# Security Settings
JWT_SECRET=7f0ee1561e341ad9ce62eace0bed766602e781ce4cd34b508a6bdbd84d075b7d

# Development Settings
XUI_ENFORCE_HTTPS=false
FORCE_HTTPS=false
DISABLE_TLS=true
URL_PROTOCOL=http

# Deployment Settings
SERVER_HOST=64.227.113.96
SERVER_USER=organic
DEPLOY_PATH=/home/organic/dev/3x-ui
EOL
    echo -e "${GREEN}.env file created successfully.${NC}"
else
    echo -e "${GREEN}.env file already exists.${NC}"
fi

# Run GitHub secrets setup
echo -e "${YELLOW}Setting up GitHub secrets from .env file...${NC}"
bash "$(dirname "$0")/setup-github-secrets.sh"

# Create Docker Compose override file for local development
echo -e "${BLUE}Creating docker-compose.override.yml for local development...${NC}"
cat > docker-compose.override.yml << EOL
# Override file for local development
services:
  3x-ui:
    environment:
      - XUI_ENFORCE_HTTPS=false
      - FORCE_HTTPS=false
      - DISABLE_TLS=true
      - URL_PROTOCOL=http
EOL
echo -e "${GREEN}docker-compose.override.yml created successfully.${NC}"

echo -e "${GREEN}CI/CD configuration synchronized successfully!${NC}"
echo -e "${YELLOW}Remember to commit your changes:${NC} npm run commit \"update CI/CD configuration\" \"Chore\"" 