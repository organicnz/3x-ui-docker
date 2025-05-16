#!/bin/bash

# Script to generate a new SSH key for GitHub Actions
# Usage: ./generate-ssh-key.sh [key_name]

# Set default key name if not provided
KEY_NAME=${1:-"github-actions"}
KEY_PATH="$HOME/.ssh/${KEY_NAME}"

# Check if key already exists
if [ -f "$KEY_PATH" ]; then
  echo "Warning: Key already exists at $KEY_PATH"
  read -p "Do you want to overwrite it? (y/n): " OVERWRITE
  if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Generate SSH key (RSA 4096 bits)
echo "Generating new SSH key at $KEY_PATH..."
ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "github-actions-${KEY_NAME}"

# Set proper permissions
chmod 600 "$KEY_PATH"
chmod 644 "${KEY_PATH}.pub"

# Display public key
echo ""
echo "Public key (add this to your server's authorized_keys):"
echo "--------------------------------------------------------"
cat "${KEY_PATH}.pub"
echo "--------------------------------------------------------"

# Format private key for GitHub Actions
echo ""
echo "Private key (add this to GitHub Actions SSH_PRIVATE_KEY secret):"
echo "----------------------------------------------------------------"
cat "$KEY_PATH"
echo "----------------------------------------------------------------"

# Instructions
echo ""
echo "GitHub Actions Setup Instructions:"
echo "1. Add the private key to your repository as a secret named SSH_PRIVATE_KEY"
echo "   - Go to your GitHub repo → Settings → Secrets and Variables → Actions"
echo "   - Click 'New repository secret'"
echo "   - Name: SSH_PRIVATE_KEY"
echo "   - Value: [paste the entire private key including BEGIN/END lines]"
echo ""
echo "2. Add the public key to your server's authorized_keys file:"
echo "   ssh-copy-id -i ${KEY_PATH}.pub user@your-server"
echo ""
echo "3. Generate SSH_KNOWN_HOSTS with:"
echo "   ./scripts/generate-known-hosts.sh your-server-hostname" 