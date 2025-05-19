#!/bin/bash
# Script to properly set up SSL certificates for 3x-ui VPN service

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

print_status "blue" "==== 3x-ui SSL Certificate Helper ===="

# Ensure we're in the correct directory
cd "$(dirname "$0")/.." || {
  print_status "red" "Failed to change to repository root directory!"
  exit 1
}

# Define DOMAIN variable or use default
DOMAIN="${VPN_DOMAIN:-service.foodshare.club}"
print_status "blue" "Using domain: $DOMAIN"

# Ensure required directories exist
print_status "green" "Ensuring certificate directories exist..."
mkdir -p "cert/$DOMAIN"

# Check if we're using Caddy for certificates
if [ -d "/home/organic/dev/caddy/caddy_data" ]; then
  print_status "green" "Caddy detected. Copying certificates from Caddy data directory..."
  
  # Find the certificates for our domain in Caddy's storage
  CADDY_CERT_DIR="/home/organic/dev/caddy/caddy_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$DOMAIN"
  
  if [ -d "$CADDY_CERT_DIR" ]; then
    # Find the most recent certificate files
    CERT_FILES=$(find "$CADDY_CERT_DIR" -name "*.crt" -o -name "*.key" | sort -r | head -2)
    
    if [ -n "$CERT_FILES" ]; then
      print_status "green" "Found Caddy certificates for $DOMAIN"
      
      # Get the certificate and key paths
      CRT_FILE=$(echo "$CERT_FILES" | grep ".crt" | head -1)
      KEY_FILE=$(echo "$CERT_FILES" | grep ".key" | head -1)
      
      if [ -n "$CRT_FILE" ] && [ -n "$KEY_FILE" ]; then
        # Copy to our cert directory with proper names
        cp "$CRT_FILE" "cert/$DOMAIN/fullchain.pem"
        cp "$KEY_FILE" "cert/$DOMAIN/privkey.pem"
        
        # Also copy to root cert directory for compatibility
        cp "$CRT_FILE" "cert/fullchain.pem"
        cp "$KEY_FILE" "cert/privkey.pem"
        
        print_status "green" "Certificates copied successfully!"
      else
        print_status "yellow" "Couldn't find both certificate and key files. Falling back to self-signed certificates."
      fi
    else
      print_status "yellow" "No certificate files found in Caddy directory. Falling back to self-signed certificates."
    fi
  else
    print_status "yellow" "Caddy certificate directory for $DOMAIN not found. Falling back to self-signed certificates."
  fi
fi

# Check if we have certificates at this point
if [ ! -f "cert/$DOMAIN/fullchain.pem" ] || [ ! -f "cert/$DOMAIN/privkey.pem" ]; then
  print_status "yellow" "Generating self-signed certificates..."
  
  # Generate self-signed certificates
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "cert/$DOMAIN/privkey.pem" \
    -out "cert/$DOMAIN/fullchain.pem" \
    -subj "/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN"
  
  # Copy to root cert directory for compatibility
  cp "cert/$DOMAIN/fullchain.pem" "cert/fullchain.pem"
  cp "cert/$DOMAIN/privkey.pem" "cert/privkey.pem"
  
  print_status "green" "Self-signed certificates generated successfully!"
fi

# Set proper permissions
chmod 644 "cert/$DOMAIN/fullchain.pem" "cert/fullchain.pem"
chmod 600 "cert/$DOMAIN/privkey.pem" "cert/privkey.pem"

print_status "green" "Certificate setup complete!"
print_status "blue" "Certificate information:"
openssl x509 -noout -text -in "cert/$DOMAIN/fullchain.pem" | grep -E "Subject:|Issuer:|Not Before:|Not After :|DNS:"

print_status "yellow" "NOTE: If using self-signed certificates, browsers will show security warnings."
print_status "yellow" "For production use, consider using Let's Encrypt certificates or Caddy's automatic SSL." 