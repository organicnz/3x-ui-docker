#!/bin/bash

# Git Repository Permission Fix Script
# This script fixes common permission issues with Git repositories

set -e  # Exit on any error

# Color definitions for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====== Fixing Git Repository Permissions ======${NC}"

# Determine the repository path
REPO_PATH="$(pwd)"
if [ ! -d "$REPO_PATH/.git" ]; then
  echo -e "${RED}Error: Not in a Git repository${NC}"
  echo -e "${YELLOW}Please run this script from the root of your Git repository${NC}"
  exit 1
fi

# Fix permissions first with regular user
echo -e "${YELLOW}Fixing Git directory ownership and permissions...${NC}"
chmod -R u+rwX .git 2>/dev/null || true
find .git -type d -exec chmod 755 {} \; 2>/dev/null || true
find .git -type f -exec chmod 644 {} \; 2>/dev/null || true

# Try with sudo if available
if command -v sudo &> /dev/null; then
  echo -e "${YELLOW}Using sudo to ensure proper permissions...${NC}"
  sudo chown -R $(whoami):$(whoami) .git 2>/dev/null || true
  sudo chmod -R 755 .git/objects 2>/dev/null || true
  sudo chmod -R 755 .git/refs 2>/dev/null || true
  sudo chmod 755 .git/HEAD .git/config 2>/dev/null || true
fi

# Verify write access to critical directories
echo -e "${YELLOW}Verifying write access to critical directories...${NC}"
if [ -w .git/objects ] && [ -w .git/refs ]; then
  echo -e "${GREEN}Critical directories are writable${NC}"
else
  echo -e "${RED}Warning: Critical Git directories are not writable${NC}"
  echo -e "${YELLOW}You may need to run this script with sudo${NC}"
fi

# Test Git operations
echo -e "${YELLOW}Testing basic Git operations...${NC}"
if git rev-parse HEAD &>/dev/null; then
  echo -e "${GREEN}Git is functioning correctly${NC}"
else
  echo -e "${RED}Git operations are still failing.${NC}"
  echo -e "${YELLOW}You may need to recreate the repository${NC}"
fi

echo -e "${GREEN}====== Git repository permissions fixed ======${NC}" 