#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if the script is run from the correct directory
if [ ! -f "env.example" ]; then
  echo -e "${RED}Error: env.example not found!${NC}"
  echo -e "Make sure you're running this script from the project root directory."
  exit 1
fi

# Check if .env already exists
if [ -f ".env" ]; then
  echo -e "${YELLOW}An .env file already exists.${NC}"
  read -p "Do you want to overwrite it? (y/N): " overwrite
  
  if [[ $overwrite != "Y" && $overwrite != "y" ]]; then
    echo -e "${BLUE}Keeping existing .env file.${NC}"
    exit 0
  fi
fi

# Copy env.example to .env
echo -e "${BLUE}Creating .env file from env.example...${NC}"
cp env.example .env
chmod 600 .env

echo -e "${GREEN}✓ .env file created successfully!${NC}"
echo -e "${YELLOW}⚠️ Please edit the .env file with your actual values:${NC}"
echo -e "  ${BLUE}nano .env${NC} or ${BLUE}code .env${NC}"
echo

# Prompt for values
read -p "Would you like to configure the .env file now? (y/N): " configure

if [[ $configure == "Y" || $configure == "y" ]]; then
  echo -e "${BLUE}Configuring .env file...${NC}"
  
  # Read VPN Domain
  read -p "Enter your VPN domain (e.g., vpn.example.com): " vpn_domain
  if [ ! -z "$vpn_domain" ]; then
    sed -i.bak "s|VPN_DOMAIN=.*|VPN_DOMAIN=$vpn_domain|g" .env
  fi
  
  # Read Admin Email
  read -p "Enter admin email: " admin_email
  if [ ! -z "$admin_email" ]; then
    sed -i.bak "s|ADMIN_EMAIL=.*|ADMIN_EMAIL=$admin_email|g" .env
  fi
  
  # Read Server Host (could be same as VPN_DOMAIN)
  echo "Server host (for SSH connections, could be same as VPN_DOMAIN)"
  read -p "Enter server host: " server_host
  if [ ! -z "$server_host" ]; then
    sed -i.bak "s|SERVER_HOST=.*|SERVER_HOST=$server_host|g" .env
  fi
  
  # Read Server User
  read -p "Enter SSH username: " server_user
  if [ ! -z "$server_user" ]; then
    sed -i.bak "s|SERVER_USER=.*|SERVER_USER=$server_user|g" .env
  fi
  
  # Read SSH Key Path
  read -p "Enter SSH key path (e.g., ~/.ssh/id_rsa): " ssh_key_path
  if [ ! -z "$ssh_key_path" ]; then
    # Expand ~ in path
    ssh_key_path="${ssh_key_path/#\~/$HOME}"
    sed -i.bak "s|SSH_KEY_PATH=.*|SSH_KEY_PATH=$ssh_key_path|g" .env
  fi
  
  # Clean up backup files
  rm -f .env.bak
  
  echo -e "${GREEN}✓ .env file configured successfully!${NC}"
else
  echo -e "${YELLOW}Please edit the .env file manually with your values.${NC}"
fi

echo -e "${BLUE}You can now use the workflow-logs.sh script to fetch logs:${NC}"
echo -e "  ${GREEN}./scripts/workflow-logs.sh -f${NC}" 