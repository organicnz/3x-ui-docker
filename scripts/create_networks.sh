#!/bin/bash

# Create Networks and Volumes Script for 3x-ui VPN Service
# This script ensures all required Docker networks and volumes exist

set -e  # Exit on any error

# Color definitions for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====== Setting up Docker Networks and Volumes ======${NC}"

# Create required networks if they don't exist
echo -e "${YELLOW}Creating required Docker networks...${NC}"
docker network create web 2>/dev/null || echo -e "${GREEN}Network 'web' already exists${NC}"
docker network create no-zero-trust-cloudflared 2>/dev/null || echo -e "${GREEN}Network 'no-zero-trust-cloudflared' already exists${NC}"
docker network create zero-trust-cloudflared 2>/dev/null || echo -e "${GREEN}Network 'zero-trust-cloudflared' already exists${NC}"
docker network create vpn-network 2>/dev/null || echo -e "${GREEN}Network 'vpn-network' already exists${NC}"

# Create required volumes if they don't exist
echo -e "${YELLOW}Creating required Docker volumes...${NC}"
docker volume create caddy_data 2>/dev/null || echo -e "${GREEN}Volume 'caddy_data' already exists${NC}"
docker volume create caddy 2>/dev/null || echo -e "${GREEN}Volume 'caddy' already exists${NC}"
docker volume create tls 2>/dev/null || echo -e "${GREEN}Volume 'tls' already exists${NC}"
docker volume create vault-data 2>/dev/null || echo -e "${GREEN}Volume 'vault-data' already exists${NC}"

# Create required directories
echo -e "${YELLOW}Creating required directories...${NC}"
mkdir -p db cert logs caddy_data caddy_config tls workflow_logs

# Fix permissions recursively with error handling
echo -e "${YELLOW}Setting proper permissions...${NC}"

# Fix root directory permissions first
chmod 755 db cert logs caddy_data caddy_config tls workflow_logs || echo -e "${YELLOW}Warning: Could not set permissions on some directories${NC}"

# Handle caddy_data specifically - this often has permission issues
if [ -d "caddy_data" ]; then
  echo -e "${YELLOW}Fixing caddy_data permissions...${NC}"
  
  # First try with current user
  find caddy_data -type d -exec chmod 755 {} \; 2>/dev/null || true
  find caddy_data -type f -exec chmod 644 {} \; 2>/dev/null || true
  
  # Try with sudo if available
  if command -v sudo &> /dev/null; then
    echo -e "${YELLOW}Using sudo to fix caddy_data permissions...${NC}"
    sudo find caddy_data -type d -exec chmod 755 {} \; 2>/dev/null || true
    sudo find caddy_data -type f -exec chmod 644 {} \; 2>/dev/null || true
    sudo chown -R $(whoami):$(whoami) caddy_data 2>/dev/null || true
  fi
fi

# Ensure logs folder has correct permissions
echo -e "${YELLOW}Setting logs directory permissions...${NC}"
chmod -R 777 logs 2>/dev/null || echo -e "${YELLOW}Warning: Could not set permissions on logs directory${NC}"

echo -e "${GREEN}====== Docker Networks and Volumes setup complete ======${NC}" 