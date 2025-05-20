#!/bin/bash

# Script to install self-signed certificate in browsers
echo "Installing self-signed certificate for service.foodshare.club..."

# Ensure certificate directory exists
mkdir -p cert/service.foodshare.club

# Check if certificates already exist
if [ ! -f cert/service.foodshare.club/fullchain.pem ]; then
  echo "Generating new self-signed certificate..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout cert/service.foodshare.club/privkey.pem \
    -out cert/service.foodshare.club/fullchain.pem \
    -subj "/CN=service.foodshare.club" \
    -addext "subjectAltName=DNS:service.foodshare.club"
  echo "Certificate generated."
else
  echo "Using existing certificate."
fi

# Detect OS and install certificate
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  echo "Installing certificate in macOS Keychain..."
  echo "Please enter your password when prompted."
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain cert/service.foodshare.club/fullchain.pem
  echo "Certificate installed in Keychain. You may need to restart your browser."
  
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux
  if [ -d "/usr/local/share/ca-certificates" ]; then
    echo "Installing certificate in Ubuntu/Debian..."
    sudo cp cert/service.foodshare.club/fullchain.pem /usr/local/share/ca-certificates/service.foodshare.club.crt
    sudo update-ca-certificates
  elif [ -d "/etc/pki/ca-trust/source/anchors" ]; then
    echo "Installing certificate in CentOS/RHEL/Fedora..."
    sudo cp cert/service.foodshare.club/fullchain.pem /etc/pki/ca-trust/source/anchors/service.foodshare.club.crt
    sudo update-ca-trust
  else
    echo "Linux distribution not recognized. Please install the certificate manually."
    echo "Certificate location: $(pwd)/cert/service.foodshare.club/fullchain.pem"
  fi
  echo "Certificate installed. You may need to restart your browser."
  
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  # Windows
  echo "On Windows, please install the certificate manually:"
  echo "1. Double-click on this file: $(pwd)/cert/service.foodshare.club/fullchain.pem"
  echo "2. Click 'Install Certificate'"
  echo "3. Select 'Current User' and click 'Next'"
  echo "4. Select 'Place all certificates in the following store' and click 'Browse'"
  echo "5. Select 'Trusted Root Certification Authorities' and click 'OK'"
  echo "6. Click 'Next' and then 'Finish'"
  echo "7. Restart your browser."
  
  # Try to open the file explorer to the certificate location
  start "$(pwd)/cert/service.foodshare.club"
else
  echo "Unsupported OS. Please install the certificate manually."
  echo "Certificate location: $(pwd)/cert/service.foodshare.club/fullchain.pem"
fi

echo ""
echo "After installing the certificate, try accessing the admin panel at:"
echo "https://service.foodshare.club:2053/BXv8SI7gBe/"
echo ""
echo "If you still encounter issues, try accessing via HTTP instead:"
echo "http://service.foodshare.club:2053/BXv8SI7gBe/" 