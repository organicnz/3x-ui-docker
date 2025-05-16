#!/bin/bash

# Script to generate SSH_KNOWN_HOSTS entry for GitHub Actions
# Usage: ./generate-known-hosts.sh <hostname_or_ip>

# Check if hostname was provided
if [ -z "$1" ]; then
  echo "Error: Please provide a hostname or IP address"
  echo "Usage: ./generate-known-hosts.sh <hostname_or_ip>"
  exit 1
fi

SERVER="$1"

# Generate SSH known hosts entry
echo "Generating SSH known hosts entry for $SERVER..."
ssh-keyscan -H "$SERVER" 2>/dev/null

echo ""
echo "Copy the above output and add it as a GitHub Secret named SSH_KNOWN_HOSTS"
echo "Note: If nothing is displayed, it means ssh-keyscan couldn't connect to the server" 