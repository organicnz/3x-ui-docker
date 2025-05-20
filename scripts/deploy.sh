#!/bin/bash
# Deployment script for 3x-ui VPN service

set -e

# Print status with color
print_status() {
  local color=$1
  local message=$2
  
  # Colors
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local NC='\033[0m' # No Color
  
  case $color in
    "red") echo -e "${RED}${message}${NC}" ;;
    "green") echo -e "${GREEN}${message}${NC}" ;;
    "yellow") echo -e "${YELLOW}${message}${NC}" ;;
    "blue") echo -e "${BLUE}${message}${NC}" ;;
    *) echo "${message}" ;;
  esac
}

print_status "blue" "==== 3x-ui VPN Deployment Helper ===="

# Ensure we're in the correct directory
cd "$(dirname "$0")/.." || {
  print_status "red" "Failed to change to repository root directory!"
  exit 1
}

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
  print_status "yellow" "docker-compose not found. Please install Docker and docker-compose."
  exit 1
fi

# Check for docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
  print_status "red" "docker-compose.yml not found in the current directory!"
  exit 1
fi

# Check for required directories
print_status "green" "Ensuring required directories exist..."
mkdir -p db cert logs cert/service.foodshare.club

# Fix certificates
print_status "green" "Ensuring SSL certificates are properly configured..."
if [ -f "scripts/fix_certificates.sh" ]; then
  chmod +x scripts/fix_certificates.sh
  ./scripts/fix_certificates.sh
else
  print_status "yellow" "Certificate fix script not found. Skipping certificate setup."
fi

# Setup networks and volumes first
print_status "green" "Setting up networks and volumes..."
./scripts/create_networks.sh

# Stop containers if they're running
print_status "green" "Stopping any running containers..."
docker-compose down || true

# Pull the latest images
print_status "green" "Pulling latest images..."
docker-compose pull

# Start the containers
print_status "green" "Starting containers..."
docker-compose up -d

# Wait for container to start
print_status "yellow" "Waiting for container to start..."
sleep 5

# Check container status
print_status "blue" "Container status:"
docker-compose ps

# Show logs
print_status "blue" "Container logs (last 20 lines):"
docker-compose logs --tail=20 3x-ui

print_status "yellow" "IMPORTANT: If the container fails to start, check the logs for errors."
print_status "yellow" "           You may need to configure your firewall using:"
print_status "yellow" "           sudo ./scripts/configure_firewall.sh"

print_status "green" "Deployment completed!"
print_status "blue" "Access your 3x-ui panel at: https://service.foodshare.club/BXv8SI7gBe/" 