#!/bin/bash

# Script to guide users through setting up GitHub Actions secrets for 3x-ui VPN
# Note: This doesn't actually set the secrets, but provides guidance

echo "=== 3x-ui VPN GitHub Actions Secret Setup Guide ==="
echo ""
echo "This script will help you prepare the necessary GitHub Action secrets."
echo "You'll need to manually add these to your GitHub repository settings."
echo ""

# 1. SSH_KNOWN_HOSTS
echo "Step 1: Generate SSH_KNOWN_HOSTS value"
echo "---------------------------------------"
read -p "Enter your server hostname or IP address: " SERVER_HOST
if [ -n "$SERVER_HOST" ]; then
  echo "Running: ssh-keyscan -H $SERVER_HOST"
  SSH_KNOWN_HOSTS=$(ssh-keyscan -H "$SERVER_HOST" 2>/dev/null)
  if [ -n "$SSH_KNOWN_HOSTS" ]; then
    echo ""
    echo "Add the following as your SSH_KNOWN_HOSTS GitHub secret:"
    echo "-------------------------------------------------------"
    echo "$SSH_KNOWN_HOSTS"
    echo "-------------------------------------------------------"
  else
    echo "Error: Could not connect to $SERVER_HOST"
  fi
fi
echo ""

# 2. VPN_DOMAIN
echo "Step 2: Set up VPN_DOMAIN"
echo "-------------------------"
read -p "Enter your VPN domain (e.g., vpn.example.com): " VPN_DOMAIN
if [ -n "$VPN_DOMAIN" ]; then
  echo "Add '$VPN_DOMAIN' as your VPN_DOMAIN GitHub secret"
fi
echo ""

# 3. ADMIN_EMAIL
echo "Step 3: Set up ADMIN_EMAIL"
echo "--------------------------"
read -p "Enter admin email for Let's Encrypt notifications: " ADMIN_EMAIL
if [ -n "$ADMIN_EMAIL" ]; then
  echo "Add '$ADMIN_EMAIL' as your ADMIN_EMAIL GitHub secret"
fi
echo ""

# 4. JWT_SECRET
echo "Step 4: Generate JWT_SECRET"
echo "--------------------------"
JWT_SECRET=$(openssl rand -base64 32)
echo "Add the following as your JWT_SECRET GitHub secret:"
echo "---------------------------------------------------"
echo "$JWT_SECRET"
echo "---------------------------------------------------"
echo ""

# 5. Panel credentials
echo "Step 5: Set up XUI panel credentials"
echo "-----------------------------------"
read -p "Enter XUI panel username (default: admin): " XUI_USERNAME
XUI_USERNAME=${XUI_USERNAME:-admin}
echo "Add '$XUI_USERNAME' as your XUI_USERNAME GitHub secret"

# Generate a secure password or ask for one
DEFAULT_PASSWORD=$(openssl rand -base64 12)
read -p "Enter XUI panel password (leave empty for auto-generated): " XUI_PASSWORD
XUI_PASSWORD=${XUI_PASSWORD:-$DEFAULT_PASSWORD}
echo "Add '$XUI_PASSWORD' as your XUI_PASSWORD GitHub secret"
echo ""

# 6. Summary
echo "Summary of GitHub Secrets to Configure"
echo "====================================="
echo "SSH_KNOWN_HOSTS: [Generated value above]"
echo "VPN_DOMAIN: $VPN_DOMAIN"
echo "ADMIN_EMAIL: $ADMIN_EMAIL"
echo "JWT_SECRET: [Generated value above]"
echo "XUI_USERNAME: $XUI_USERNAME"
echo "XUI_PASSWORD: $XUI_PASSWORD"
echo ""

echo "Additional recommended secrets:"
echo "- XRAY_VMESS_AEAD_FORCED: false (already in docker-compose.yml)"
echo "- PANEL_PATH: BXv8SI7gBe (already in docker-compose.yml)"
echo "- BACKUP_RETENTION_DAYS: 7 (optional, for backup configuration)"
echo "- NOTIFICATION_WEBHOOK: [Your webhook URL] (optional, for notifications)"
echo "- TELEGRAM_BOT_TOKEN: [Telegram token] (optional, for Telegram notifications)"
echo ""

echo "To add these secrets:"
echo "1. Go to your GitHub repository"
echo "2. Click on 'Settings' > 'Secrets and variables' > 'Actions'"
echo "3. Click 'New repository secret' and add each secret"
echo ""
echo "For security reasons, this script doesn't automatically set GitHub secrets."
echo "=== Setup guide complete ===" 