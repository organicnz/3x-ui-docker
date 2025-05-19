#!/bin/bash
# Script to configure firewall rules for 3x-ui VPN service

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  print_status "red" "Please run as root"
  exit 1
fi

print_status "blue" "==== Configuring Firewall Rules for 3x-ui VPN ===="

# Check if ufw is installed
if ! command -v ufw &> /dev/null; then
  print_status "yellow" "UFW not found. Installing..."
  apt-get update
  apt-get install -y ufw
fi

# Check if firewall is active
if ! ufw status | grep -q "Status: active"; then
  print_status "yellow" "Firewall is not active. Enabling..."
  ufw --force enable
fi

# Allow SSH (important to prevent lockout)
print_status "green" "Ensuring SSH access is allowed..."
ufw allow ssh

# Allow essential ports for 3x-ui
print_status "green" "Opening required ports for 3x-ui..."

# Admin panel
ufw allow 2053/tcp

# HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Additional ports for XRay protocols
ufw allow 54321/tcp
ufw allow 54321/udp

print_status "green" "Firewall configuration complete!"
print_status "blue" "Current firewall status:"
ufw status

print_status "yellow" "IMPORTANT: If you add more XRay inbound protocols,"
print_status "yellow" "           make sure to update firewall rules accordingly." 