#!/bin/bash
# Quick fix for SSL certificate issue

# Instructions:
# 1. Copy this file to your server
# 2. Make it executable: chmod +x quick-cert-fix.sh
# 3. Run it with sudo: sudo ./quick-cert-fix.sh

set -e
DOMAIN="service.foodshare.club"
DEPLOY_PATH="$HOME/dev/3x-ui"
CERT_DIR="$DEPLOY_PATH/cert/$DOMAIN"

echo "Creating certificate directory..."
mkdir -p "$CERT_DIR"

# Create self-signed certificate as a fallback
echo "Creating self-signed certificates..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERT_DIR/privkey.pem" \
  -out "$CERT_DIR/fullchain.pem" \
  -subj "/CN=$DOMAIN/O=3x-ui/C=US"

# Fix permissions
echo "Setting permissions..."
chown -R $(whoami):$(whoami) "$CERT_DIR"
chmod 644 "$CERT_DIR/fullchain.pem"
chmod 600 "$CERT_DIR/privkey.pem"

echo "Restarting 3x-ui container..."
cd "$DEPLOY_PATH"
docker-compose restart 3x-ui

echo "Certificate fix complete. Please check container logs:"
echo "docker logs 3x-ui" 