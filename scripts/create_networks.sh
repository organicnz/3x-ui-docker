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
chmod -R 755 db cert logs caddy_data caddy_config tls

echo -e "${GREEN}====== Docker Networks and Volumes setup complete ======${NC}" 