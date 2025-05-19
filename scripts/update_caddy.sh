#!/bin/bash
# Script to update Caddy configuration for 3x-ui VPN service

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

print_status "blue" "==== 3x-ui VPN Caddy Configuration Helper ===="

# Ensure we're in the correct directory
cd "$(dirname "$0")/.." || {
  print_status "red" "Failed to change to repository root directory!"
  exit 1
}

# Define variables
CADDY_PATH="/home/organic/dev/caddy"
CADDY_CONFIG_FILE="$CADDY_PATH/caddy_config/Caddyfile"
DOMAIN="${VPN_DOMAIN:-service.foodshare.club}"

# Check if Caddy configuration exists
if [ ! -d "$CADDY_PATH" ]; then
  print_status "yellow" "Caddy directory not found at $CADDY_PATH."
  print_status "yellow" "If you're using Caddy, please specify the correct path:"
  print_status "yellow" "CADDY_PATH=/your/path/to/caddy ./scripts/update_caddy.sh"
  exit 1
fi

if [ ! -f "$CADDY_CONFIG_FILE" ]; then
  print_status "yellow" "Caddyfile not found at $CADDY_CONFIG_FILE."
  print_status "yellow" "Creating new Caddyfile from our template..."
  
  # Create the caddy_config directory if it doesn't exist
  mkdir -p "$CADDY_PATH/caddy_config"
  
  # Check if we have a Caddyfile template
  if [ -f "docs/caddy-config.md" ]; then
    # Extract the Caddyfile content from the markdown
    print_status "green" "Extracting Caddyfile from docs/caddy-config.md..."
    sed -n '/```caddyfile/,/```/ p' docs/caddy-config.md | sed '1d;$d' > "$CADDY_CONFIG_FILE"
    
    # Replace domain if needed
    if [ "$DOMAIN" != "service.foodshare.club" ]; then
      print_status "yellow" "Replacing domain in Caddyfile..."
      sed -i "s/service.foodshare.club/$DOMAIN/g" "$CADDY_CONFIG_FILE"
    fi
    
    print_status "green" "Caddyfile created at $CADDY_CONFIG_FILE"
  else
    print_status "red" "Template file docs/caddy-config.md not found!"
    print_status "red" "Cannot create Caddyfile automatically."
    exit 1
  fi
else
  print_status "green" "Caddyfile found. Checking for browsing-topics issue..."
  
  # Check if the file contains the browsing-topics issue
  if grep -q "browsing-topics" "$CADDY_CONFIG_FILE"; then
    print_status "yellow" "Found browsing-topics in Permissions-Policy header. Fixing..."
    
    # Create a backup of the current Caddyfile
    cp "$CADDY_CONFIG_FILE" "$CADDY_CONFIG_FILE.bak"
    print_status "green" "Created backup at $CADDY_CONFIG_FILE.bak"
    
    # Replace the Permissions-Policy line without browsing-topics
    sed -i 's/\(Permissions-Policy "[^"]*\)browsing-topics=[^"]*\("[^"]*\)/\1\2/' "$CADDY_CONFIG_FILE"
    
    print_status "green" "Removed browsing-topics from Permissions-Policy header."
  else
    print_status "green" "No browsing-topics issue found in Caddyfile."
  fi
fi

# Reload Caddy if possible
print_status "yellow" "Attempting to reload Caddy configuration..."
if [ -d "$CADDY_PATH" ]; then
  cd "$CADDY_PATH"
  
  if command -v docker-compose &> /dev/null; then
    docker-compose exec caddy caddy reload 2>/dev/null || {
      print_status "yellow" "Could not automatically reload Caddy. Please reload manually:"
      print_status "yellow" "cd $CADDY_PATH && docker-compose exec caddy caddy reload"
    }
  else
    print_status "yellow" "docker-compose not found. Please reload Caddy manually:"
    print_status "yellow" "cd $CADDY_PATH && docker-compose exec caddy caddy reload"
  fi
fi

print_status "green" "Caddy configuration update complete!"
print_status "blue" "If you encounter any issues, please check:"
print_status "blue" "1. Caddy logs: docker-compose logs caddy"
print_status "blue" "2. 3x-ui logs: docker-compose logs 3x-ui"
print_status "blue" "3. For SSL issues: run ./scripts/fix_certificates.sh" 