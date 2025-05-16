#!/bin/bash

# Script to generate a secure JWT_SECRET and update the .env file
# Usage: ./scripts/generate-jwt-secret.sh

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Generate a secure random string
echo -e "${BLUE}Generating a secure JWT_SECRET...${NC}"
JWT_SECRET=$(openssl rand -hex 32)

# Check if .env file exists
if [ ! -f .env ]; then
  echo "Error: .env file does not exist."
  exit 1
fi

# Update JWT_SECRET in .env file
echo -e "${BLUE}Updating JWT_SECRET in .env file...${NC}"
sed -i.bak "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
rm -f .env.bak

echo -e "${GREEN}JWT_SECRET has been updated in .env file.${NC}"
echo -e "${BLUE}New JWT_SECRET:${NC} $JWT_SECRET"
echo
echo "Remember to keep this value secure and don't share it!" 