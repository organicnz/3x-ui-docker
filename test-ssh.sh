#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if secrets are set
echo -e "${YELLOW}Checking GitHub Secrets:${NC}"

# Get repository secrets (limited info available)
SECRETS=$(gh api repos/organicnz/3x-ui-docker/actions/secrets --silent | jq -r '.secrets[].name' 2>/dev/null)

if [ -z "$SECRETS" ]; then
    echo -e "${RED}❌ Failed to retrieve secrets or no secrets found${NC}"
else
    echo -e "${GREEN}Found secrets:${NC}"
    echo "$SECRETS" | while read -r secret; do
        echo -e "  ✅ $secret"
    done
fi

echo -e "\n${YELLOW}Testing SSH Key Authentication:${NC}"
read -p "Enter your server hostname or IP: " SERVER_HOST
read -p "Enter your SSH username: " SSH_USER
read -p "Enter path to SSH private key [~/.ssh/id_ed25519]: " SSH_KEY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_ed25519}

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}❌ SSH key not found at $SSH_KEY_PATH${NC}"
    exit 1
fi

# Test SSH connection
echo -e "\n${YELLOW}Attempting SSH connection with key...${NC}"
ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SERVER_HOST" "echo -e '${GREEN}✅ SSH connection successful${NC}'" || echo -e "${RED}❌ SSH connection failed${NC}"

# Test rsync
echo -e "\n${YELLOW}Testing rsync command (similar to GitHub Action)...${NC}"
TEMPFILE=$(mktemp)
echo "Test file for rsync" > "$TEMPFILE"

echo "Running: rsync -avz -e \"ssh -i $SSH_KEY_PATH\" $TEMPFILE $SSH_USER@$SERVER_HOST:/tmp/test-rsync"
rsync -avz -e "ssh -i $SSH_KEY_PATH" "$TEMPFILE" "$SSH_USER@$SERVER_HOST:/tmp/test-rsync" && echo -e "${GREEN}✅ rsync test successful${NC}" || echo -e "${RED}❌ rsync test failed${NC}"

rm "$TEMPFILE"

echo -e "\n${YELLOW}Summarizing findings:${NC}"
echo "1. If SSH connection was successful but rsync failed, check permissions on target directory"
echo "2. If both failed, verify your SSH key and server configuration"
echo "3. Make sure all GitHub secrets are properly set"
echo "4. Verify that the SERVER_HOST, SERVER_USER, and SSH_PRIVATE_KEY secrets match what works with manual SSH" 