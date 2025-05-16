#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Pull Changes to VPS${NC}"
read -p "Enter your server hostname or IP: " SERVER_HOST
read -p "Enter your SSH username: " SSH_USER
read -p "Enter path to SSH private key [~/.ssh/id_ed25519]: " SSH_KEY_PATH
read -p "Enter deployment path on server: " DEPLOY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_ed25519}

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}❌ SSH key not found at $SSH_KEY_PATH${NC}"
    exit 1
fi

# Test SSH connection first
echo -e "\n${YELLOW}Testing SSH connection...${NC}"
ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SERVER_HOST" "echo -e '${GREEN}✅ SSH connection successful${NC}'" || {
    echo -e "${RED}❌ SSH connection failed${NC}"
    exit 1
}

# Transfer files to VPS
echo -e "\n${YELLOW}Transferring files to VPS...${NC}"
rsync -avz --exclude='.git/' \
  --exclude='.github/' \
  --exclude='node_modules/' \
  --exclude='.gitignore' \
  --exclude='.cursor/' \
  --exclude='workflow_logs/' \
  ./ "$SSH_USER@$SERVER_HOST:$DEPLOY_PATH" || {
    echo -e "${RED}❌ File transfer failed${NC}"
    exit 1
}

# Restart container on VPS
echo -e "\n${YELLOW}Restarting container on VPS...${NC}"
ssh -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_HOST" "cd $DEPLOY_PATH && docker-compose down && docker-compose up -d && docker-compose ps" || {
    echo -e "${RED}❌ Container restart failed${NC}"
    exit 1
}

echo -e "\n${GREEN}✅ Changes have been successfully pulled to the VPS and service restarted!${NC}" 