#!/bin/bash

# Script to test SSH connectivity to the remote server
# Usage: ./test-ssh-connectivity.sh

set -e

# Load environment variables
if [ -f ".env" ]; then
  source .env
else
  echo "Error: .env file not found. Please create it with SERVER_HOST and SERVER_USER variables."
  exit 1
fi

# Check required variables
if [ -z "$SERVER_HOST" ]; then
  echo "Error: SERVER_HOST environment variable not set"
  exit 1
fi

if [ -z "$SERVER_USER" ]; then
  echo "Error: SERVER_USER environment variable not set"
  exit 1
fi

# Optional SSH key path
if [ -n "$SSH_KEY_PATH" ]; then
  SSH_KEY_OPTION="-i $SSH_KEY_PATH"
else
  SSH_KEY_OPTION=""
fi

echo "🔍 Testing SSH connection to ${SERVER_USER}@${SERVER_HOST}..."

# Try to connect with a simple command
if ssh $SSH_KEY_OPTION -o BatchMode=yes -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_HOST} "echo '✅ SSH connection successful'"; then
  echo "✅ SSH connection test passed!"
  
  # Check if the deploy path exists
  if [ -n "$DEPLOY_PATH" ]; then
    echo "🔍 Checking if deployment path exists..."
    if ssh $SSH_KEY_OPTION ${SERVER_USER}@${SERVER_HOST} "[ -d \"$DEPLOY_PATH\" ] && echo '✅ Directory exists' || echo '❌ Directory does not exist'"; then
      echo "🔍 Checking Docker installation..."
      ssh $SSH_KEY_OPTION ${SERVER_USER}@${SERVER_HOST} "command -v docker &> /dev/null && echo '✅ Docker is installed' || echo '❌ Docker is not installed'"
      
      echo "🔍 Checking Docker Compose installation..."
      ssh $SSH_KEY_OPTION ${SERVER_USER}@${SERVER_HOST} "command -v docker-compose &> /dev/null && echo '✅ Docker Compose is installed' || echo '❌ Docker Compose is not installed'"
    fi
  fi
else
  echo "❌ SSH connection failed!"
  echo "Please check your SSH configuration:"
  echo "  - Make sure the server is reachable at ${SERVER_HOST}"
  echo "  - Verify that SSH key authentication is set up correctly"
  echo "  - Check if your SSH key is added to the SSH agent"
  echo "  - Ensure that the server is allowing SSH connections"
  exit 1
fi

echo "✅ Test completed successfully!" 