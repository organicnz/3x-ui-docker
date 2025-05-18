#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==== 3x-ui VPN Git Repository Fix ====${NC}"
echo -e "${YELLOW}This script will fix the Git repository issues${NC}"
echo

# Check if we're in the right directory
REPO_DIR="$HOME/dev/3x-ui"
if [ "$(pwd)" != "$REPO_DIR" ]; then
  echo -e "${YELLOW}Changing to the repository directory: $REPO_DIR${NC}"
  cd "$REPO_DIR"
fi

# Check if .git directory exists
if [ ! -d ".git" ]; then
  echo -e "${RED}No .git directory found. Initializing Git repository...${NC}"
  git init
  echo -e "${GREEN}Git repository initialized.${NC}"
else
  echo -e "${GREEN}Git repository exists.${NC}"
fi

# Check remote configuration
if ! git remote -v | grep -q "origin"; then
  echo -e "${YELLOW}Setting up remote origin...${NC}"
  git remote add origin https://github.com/organicnz/3x-ui-docker.git
  echo -e "${GREEN}Remote origin added.${NC}"
else
  echo -e "${GREEN}Remote origin exists.${NC}"
fi

# Fetch latest changes
echo -e "${YELLOW}Fetching latest changes...${NC}"
git fetch --all || {
  echo -e "${RED}Failed to fetch. Setting up remote again...${NC}"
  git remote remove origin
  git remote add origin https://github.com/organicnz/3x-ui-docker.git
  git fetch --all
}

# Reset to match the remote repository
echo -e "${YELLOW}Resetting to match remote repository...${NC}"
git reset --hard origin/main

# Ensure the necessary directories exist
echo -e "${YELLOW}Creating required directories...${NC}"
mkdir -p db cert logs cert/service.foodshare.club

# Ensure database file exists
if [ ! -f "db/x-ui.db" ]; then
  echo -e "${YELLOW}Creating db/x-ui.db placeholder...${NC}"
  touch db/x-ui.db
fi

# Ensure proper permissions
echo -e "${YELLOW}Setting correct permissions...${NC}"
chmod -R 755 .
chmod -R 777 logs
chmod 644 db/x-ui.db

echo -e "${GREEN}Repository has been fixed successfully!${NC}"
echo -e "${YELLOW}Current repository status:${NC}"
git status

echo -e "${GREEN}Done!${NC}" 