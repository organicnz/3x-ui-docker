#!/bin/bash

# Script to verify SSH private key format for GitHub Actions
# Usage: ./check-ssh-key.sh path/to/private_key

# Check if key path was provided
if [ -z "$1" ]; then
  echo "Error: Please provide the path to your SSH private key"
  echo "Usage: ./check-ssh-key.sh path/to/private_key"
  exit 1
fi

KEY_PATH="$1"

# Check if the file exists
if [ ! -f "$KEY_PATH" ]; then
  echo "Error: Key file not found at $KEY_PATH"
  exit 1
fi

# Check if the key file has correct begin/end markers
if ! grep -q "BEGIN.*PRIVATE KEY" "$KEY_PATH"; then
  echo "Error: Key file does not contain BEGIN PRIVATE KEY marker"
  echo "Make sure the key starts with -----BEGIN OPENSSH PRIVATE KEY----- or similar"
  exit 1
fi

if ! grep -q "END.*PRIVATE KEY" "$KEY_PATH"; then
  echo "Error: Key file does not contain END PRIVATE KEY marker"
  echo "Make sure the key ends with -----END OPENSSH PRIVATE KEY----- or similar"
  exit 1
fi

# Check file permissions
PERMS=$(stat -c "%a" "$KEY_PATH" 2>/dev/null || stat -f "%Lp" "$KEY_PATH")
if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
  echo "Warning: Key file has incorrect permissions: $PERMS"
  echo "Recommended: chmod 600 $KEY_PATH"
fi

# Check key format
echo "Validating key format..."
if ! ssh-keygen -y -f "$KEY_PATH" >/dev/null 2>&1; then
  echo "Error: The key appears to be invalid or in the wrong format"
  echo "Make sure it's a complete private key with no extra spaces or characters"
  exit 1
fi

# Format key for GitHub Actions - show how it should be formatted
echo ""
echo "✅ Key format validation passed!"
echo ""
echo "For GitHub Actions SSH_PRIVATE_KEY secret, copy the key INCLUDING the BEGIN/END lines:"
echo "------------------------------------------------"
cat "$KEY_PATH" | sed 's/^/| /'
echo "------------------------------------------------"
echo ""
echo "When adding to GitHub Secrets:"
echo "1. Copy the ENTIRE key including BEGIN and END lines"
echo "2. Ensure no extra spaces at beginning or end"
echo "3. Keep all line breaks as they are in the file"
echo ""
echo "Now generate your known_hosts with: ./scripts/generate-known-hosts.sh your-server-hostname" 