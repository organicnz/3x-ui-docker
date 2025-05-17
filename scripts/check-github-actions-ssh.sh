#!/bin/bash

# Script to check and fix GitHub Actions SSH connectivity issues
# Usage: ./check-github-actions-ssh.sh

set -e

echo "======================================================================"
echo "🔍 GITHUB ACTIONS SSH CONNECTIVITY CHECKER"
echo "======================================================================"

# Load environment variables
if [ -f ".env" ]; then
  source .env
  echo "✅ Loaded environment variables from .env file"
else
  echo "❌ .env file not found. Creating from template..."
  if [ -f ".env.example" ]; then
    cp .env.example .env
    echo "✅ Created .env file from .env.example template"
    echo "⚠️  Please edit the .env file to set your specific configuration"
    source .env
  else
    echo "❌ .env.example file not found. Please create an .env file manually."
    exit 1
  fi
fi

# Check GitHub repository secrets (simulated for local environment)
echo ""
echo "======================================================================"
echo "🔑 CHECKING REQUIRED SECRETS"
echo "======================================================================"
echo "For GitHub Actions to connect via SSH, you need these repository secrets:"
echo ""

required_secrets=("SSH_PRIVATE_KEY" "SSH_KNOWN_HOSTS" "SERVER_HOST" "SERVER_USER" "DEPLOY_PATH")

for secret in "${required_secrets[@]}"; do
  if [ -n "${!secret}" ]; then
    echo "✅ $secret: Configured"
  else
    echo "❌ $secret: Missing"
  fi
done

echo ""
echo "======================================================================"
echo "🔧 SSH KEY GENERATION GUIDE"
echo "======================================================================"
echo "If you're missing SSH_PRIVATE_KEY or SSH_KNOWN_HOSTS, follow these steps:"
echo ""
echo "1. Generate an SSH key pair (if you don't have one):"
echo "   ssh-keygen -t ed25519 -C 'github-actions-deploy'"
echo ""
echo "2. Copy the private key content to GitHub repository secret SSH_PRIVATE_KEY:"
echo "   cat ~/.ssh/id_ed25519 | pbcopy"
echo ""
echo "3. Add the public key to your server's authorized_keys:"
echo "   ssh-copy-id -i ~/.ssh/id_ed25519.pub username@your-server"
echo ""
echo "4. Generate SSH_KNOWN_HOSTS content:"
echo "   ssh-keyscan -t rsa your-server-host >> known_hosts_content"
echo "   cat known_hosts_content | pbcopy"
echo ""
echo "5. Copy the content to GitHub repository secret SSH_KNOWN_HOSTS"

echo ""
echo "======================================================================"
echo "🔄 TESTING SSH CONNECTION"
echo "======================================================================"

# Test SSH connection if credentials are available
if [ -n "$SERVER_HOST" ] && [ -n "$SERVER_USER" ]; then
  echo "Testing SSH connection to ${SERVER_USER}@${SERVER_HOST}..."
  
  if [ -n "$SSH_KEY_PATH" ]; then
    if [ -f "$SSH_KEY_PATH" ]; then
      echo "Using SSH key from: $SSH_KEY_PATH"
      if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_HOST} "echo '✅ SSH connection successful'" 2>/dev/null; then
        echo "✅ SSH connection test passed!"
      else
        echo "❌ SSH connection test failed using specified SSH key"
        echo "   Check if the key is correct and added to the server's authorized_keys"
      fi
    else
      echo "❌ Specified SSH_KEY_PATH does not exist: $SSH_KEY_PATH"
    fi
  else
    echo "No SSH_KEY_PATH specified, trying with default SSH configuration..."
    if ssh -o BatchMode=yes -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_HOST} "echo '✅ SSH connection successful'" 2>/dev/null; then
      echo "✅ SSH connection test passed with default SSH configuration!"
    else
      echo "❌ SSH connection test failed with default SSH configuration"
    fi
  fi
else
  echo "❌ Cannot test SSH connection: SERVER_HOST or SERVER_USER not set"
fi

echo ""
echo "======================================================================"
echo "📋 GITHUB ACTIONS WORKFLOW CHECKS"
echo "======================================================================"

# Check for workflow files
if [ -d ".github/workflows" ]; then
  echo "Checking GitHub Actions workflow files..."
  workflow_files=$(ls -1 .github/workflows/*.yml 2>/dev/null | wc -l)
  
  if [ "$workflow_files" -gt 0 ]; then
    echo "✅ Found $workflow_files workflow file(s):"
    ls -1 .github/workflows/*.yml
    
    # Check if workflows use SSH properly
    echo ""
    echo "Checking SSH configuration in workflow files..."
    for workflow in .github/workflows/*.yml; do
      echo "Analyzing $workflow..."
      
      # Check for proper SSH key setup
      if grep -q "ssh-private-key: \${{ secrets.SSH_PRIVATE_KEY }}" "$workflow"; then
        echo "✅ Found proper SSH private key configuration"
      else
        echo "⚠️  No proper SSH private key configuration found"
        echo "   Should contain: ssh-private-key: \${{ secrets.SSH_PRIVATE_KEY }}"
      fi
      
      # Check for known hosts setup
      if grep -q "SSH_KNOWN_HOSTS" "$workflow"; then
        echo "✅ Found reference to SSH_KNOWN_HOSTS"
      else
        echo "⚠️  No reference to SSH_KNOWN_HOSTS found"
      fi
      
      # Check for SCP action configuration
      if grep -q "appleboy/scp-action" "$workflow"; then
        if grep -q "key: \${{ secrets.SSH_PRIVATE_KEY }}" "$workflow"; then
          echo "✅ SCP action properly configured with SSH key"
        else
          echo "❌ SCP action missing key parameter"
          echo "   Should include: key: \${{ secrets.SSH_PRIVATE_KEY }}"
        fi
      fi
      
      echo ""
    done
  else
    echo "❌ No workflow files found in .github/workflows/"
  fi
else
  echo "❌ .github/workflows directory not found"
fi

echo ""
echo "======================================================================"
echo "🛠️  RECOMMENDATIONS"
echo "======================================================================"

# Provide recommendations based on findings
echo "Based on the checks performed, here are recommendations to fix SSH issues:"
echo ""

# Check if workflows directory exists
if [ ! -d ".github/workflows" ]; then
  echo "1. Create the .github/workflows directory:"
  echo "   mkdir -p .github/workflows"
  echo ""
fi

# Check if workflow file exists
if [ "$workflow_files" -eq 0 ]; then
  echo "2. Create a GitHub Actions workflow file:"
  echo "   touch .github/workflows/3x-ui-workflow.yml"
  echo ""
fi

# Output recommendation for fixing SCP action
echo "3. Make sure any SCP actions include the key parameter:"
echo ""
echo "   - name: Transfer files"
echo "     uses: appleboy/scp-action@master"
echo "     with:"
echo "       host: \${{ secrets.SERVER_HOST }}"
echo "       username: \${{ secrets.SERVER_USER }}"
echo "       key: \${{ secrets.SSH_PRIVATE_KEY }}  # This line is essential!"
echo "       source: \"files-to-copy\""
echo "       target: \"\${{ secrets.DEPLOY_PATH }}\""
echo ""

echo "4. Ensure SSH keys are properly set up in workflow steps:"
echo ""
echo "   - name: Set up SSH"
echo "     uses: webfactory/ssh-agent@v0.7.0"
echo "     with:"
echo "       ssh-private-key: \${{ secrets.SSH_PRIVATE_KEY }}"
echo ""
echo "   - name: Add to known hosts"
echo "     run: |"
echo "       mkdir -p ~/.ssh"
echo "       echo \"\${{ secrets.SSH_KNOWN_HOSTS }}\" >> ~/.ssh/known_hosts"
echo ""

echo "======================================================================"
echo "✅ Check completed!"
echo "======================================================================" 