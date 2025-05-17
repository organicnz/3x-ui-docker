#!/bin/bash

# Script to help users set up GitHub repository secrets for SSH deployments
# Usage: ./setup-github-secrets.sh

set -e

echo "======================================================================"
echo "🔑 GITHUB REPOSITORY SECRETS SETUP HELPER"
echo "======================================================================"
echo "This script will guide you through setting up the necessary GitHub"
echo "repository secrets for SSH-based deployments with GitHub Actions."
echo ""

# Function to create a temporary file for sensitive data
create_temp_file() {
  local temp_file
  temp_file=$(mktemp)
  echo "$temp_file"
}

# Function to securely delete a file
secure_delete() {
  local file=$1
  if [ -f "$file" ]; then
    rm -P "$file" 2>/dev/null || rm "$file"
    echo "✅ Temporary file securely deleted"
  fi
}

# Function to copy to clipboard based on OS
copy_to_clipboard() {
  local text=$1
  
  if [ "$(uname)" == "Darwin" ]; then
    # macOS
    echo "$text" | pbcopy
    echo "✅ Copied to clipboard"
  elif [ -x "$(command -v xclip)" ]; then
    # Linux with xclip
    echo "$text" | xclip -selection clipboard
    echo "✅ Copied to clipboard using xclip"
  elif [ -x "$(command -v xsel)" ]; then
    # Linux with xsel
    echo "$text" | xsel --clipboard
    echo "✅ Copied to clipboard using xsel"
  else
    # Fallback
    echo "⚠️  Could not copy to clipboard. Please copy the content manually."
    echo "$text"
  fi
}

# Step 1: Get repository information
echo "======================================================================"
echo "STEP 1: IDENTIFY YOUR GITHUB REPOSITORY"
echo "======================================================================"

# Try to get repository from git config
repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
repo_owner=""
repo_name=""

if [[ $repo_url =~ github.com[:/]([^/]+)/([^/.]+) ]]; then
  repo_owner=${BASH_REMATCH[1]}
  repo_name=${BASH_REMATCH[2]}
  echo "✅ Detected GitHub repository: $repo_owner/$repo_name"
else
  echo "⚠️  Could not automatically detect GitHub repository."
  echo "Please enter your GitHub repository information manually:"
  
  echo -n "GitHub username or organization: "
  read -r repo_owner
  
  echo -n "Repository name: "
  read -r repo_name
fi

# Confirm repository information
echo ""
echo "Repository: $repo_owner/$repo_name"
echo -n "Is this correct? (y/n): "
read -r confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
  echo "Please restart the script with the correct repository information."
  exit 1
fi

# Create repository URL
repo_settings_url="https://github.com/$repo_owner/$repo_name/settings/secrets/actions"
echo ""
echo "You will need to add secrets at:"
echo "$repo_settings_url"
echo ""

# Step 2: SSH Key generation
echo "======================================================================"
echo "STEP 2: SSH KEY SETUP"
echo "======================================================================"
echo "You need an SSH key pair for GitHub Actions to connect to your server."
echo ""

# Check if user wants to generate a new key or use existing
echo "Do you want to:"
echo "1) Generate a new SSH key pair (recommended)"
echo "2) Use an existing SSH key pair"
echo -n "Enter your choice (1/2): "
read -r ssh_key_choice

ssh_key_file=""
ssh_private_key=""

if [ "$ssh_key_choice" == "1" ]; then
  # Generate new SSH key
  echo ""
  echo "Generating a new SSH key pair for GitHub Actions..."
  
  # Ask for key file path
  echo -n "Enter a name for your SSH key (default: github-actions-deploy): "
  read -r key_name
  
  if [ -z "$key_name" ]; then
    key_name="github-actions-deploy"
  fi
  
  ssh_key_file="$HOME/.ssh/${key_name}"
  
  # Check if key already exists
  if [ -f "$ssh_key_file" ]; then
    echo "⚠️  Warning: SSH key '$ssh_key_file' already exists!"
    echo -n "Do you want to overwrite it? (y/n): "
    read -r overwrite
    
    if [[ ! $overwrite =~ ^[Yy]$ ]]; then
      echo "Please restart the script with a different key name."
      exit 1
    fi
  fi
  
  # Generate SSH key
  ssh-keygen -t ed25519 -f "$ssh_key_file" -C "github-actions-deploy-$repo_name" -N ""
  
  echo "✅ SSH key pair generated successfully!"
  echo "   Private key: $ssh_key_file"
  echo "   Public key: $ssh_key_file.pub"
  
  # Read private key
  ssh_private_key=$(cat "$ssh_key_file")
else
  # Use existing SSH key
  echo ""
  echo "Please enter the path to your existing SSH private key:"
  echo -n "SSH private key path (default: ~/.ssh/id_ed25519): "
  read -r ssh_key_file
  
  if [ -z "$ssh_key_file" ]; then
    ssh_key_file="$HOME/.ssh/id_ed25519"
  fi
  
  # Expand tilde to home directory
  ssh_key_file="${ssh_key_file/#\~/$HOME}"
  
  # Check if key exists
  if [ ! -f "$ssh_key_file" ]; then
    echo "❌ Error: SSH key file does not exist: $ssh_key_file"
    exit 1
  fi
  
  # Read private key
  ssh_private_key=$(cat "$ssh_key_file")
  
  echo "✅ Using existing SSH key: $ssh_key_file"
fi

# Step 3: Server information
echo ""
echo "======================================================================"
echo "STEP 3: SERVER INFORMATION"
echo "======================================================================"

echo -n "Enter your server hostname or IP address: "
read -r server_host

echo -n "Enter your server username: "
read -r server_user

echo -n "Enter deployment path on server (default: /opt/3x-ui): "
read -r deploy_path

if [ -z "$deploy_path" ]; then
  deploy_path="/opt/3x-ui"
fi

# Step 4: Generate known hosts
echo ""
echo "======================================================================"
echo "STEP 4: GENERATE SSH KNOWN HOSTS"
echo "======================================================================"
echo "Generating SSH known hosts entry for your server..."

known_hosts_temp=$(create_temp_file)
ssh-keyscan -H "$server_host" > "$known_hosts_temp" 2>/dev/null

if [ ! -s "$known_hosts_temp" ]; then
  echo "❌ Error: Could not retrieve SSH host key. Is the server reachable?"
  secure_delete "$known_hosts_temp"
  exit 1
fi

# Read known hosts
ssh_known_hosts=$(cat "$known_hosts_temp")
secure_delete "$known_hosts_temp"

echo "✅ Generated SSH known hosts entry for $server_host"

# Step 5: Deploy SSH public key to server
echo ""
echo "======================================================================"
echo "STEP 5: DEPLOY SSH PUBLIC KEY TO SERVER"
echo "======================================================================"
echo "You need to add the SSH public key to your server's authorized_keys."
echo ""

echo "Do you want to:"
echo "1) Automatically deploy the SSH public key to your server (requires password)"
echo "2) Manually add the SSH public key to your server"
echo -n "Enter your choice (1/2): "
read -r deploy_choice

if [ "$deploy_choice" == "1" ]; then
  # Try to use ssh-copy-id
  if [ -x "$(command -v ssh-copy-id)" ]; then
    echo "Deploying SSH public key to ${server_user}@${server_host}..."
    ssh-copy-id -i "${ssh_key_file}.pub" "${server_user}@${server_host}"
    echo "✅ SSH public key deployed successfully!"
  else
    echo "❌ Error: ssh-copy-id command not found. You'll need to manually deploy the key."
    echo "   Public key content:"
    cat "${ssh_key_file}.pub"
  fi
else
  # Manual instructions
  echo ""
  echo "Please add the following public key to your server's authorized_keys file:"
  echo ""
  cat "${ssh_key_file}.pub"
  echo ""
  echo "You can do this by running these commands on your server:"
  echo "   mkdir -p ~/.ssh"
  echo "   chmod 700 ~/.ssh"
  echo "   echo '$(cat "${ssh_key_file}.pub")' >> ~/.ssh/authorized_keys"
  echo "   chmod 600 ~/.ssh/authorized_keys"
  
  # Copy to clipboard
  echo ""
  echo -n "Copy public key to clipboard? (y/n): "
  read -r copy_pubkey
  
  if [[ $copy_pubkey =~ ^[Yy]$ ]]; then
    copy_to_clipboard "$(cat "${ssh_key_file}.pub")"
  fi
fi

# Step 6: Create .env file
echo ""
echo "======================================================================"
echo "STEP 6: CREATE LOCAL ENVIRONMENT FILE"
echo "======================================================================"

echo "Creating/updating .env file with server information..."

if [ -f ".env" ]; then
  # Update existing .env file
  grep -v "^SERVER_HOST=" .env > .env.tmp
  grep -v "^SERVER_USER=" .env.tmp > .env
  grep -v "^DEPLOY_PATH=" .env > .env.tmp
  grep -v "^SSH_KEY_PATH=" .env.tmp > .env
  rm -f .env.tmp
fi

# Add/update server information in .env
echo "SERVER_HOST=$server_host" >> .env
echo "SERVER_USER=$server_user" >> .env
echo "DEPLOY_PATH=$deploy_path" >> .env
echo "SSH_KEY_PATH=$ssh_key_file" >> .env

echo "✅ Updated .env file with server information"

# Step 7: Copy secrets to GitHub
echo ""
echo "======================================================================"
echo "STEP 7: ADD SECRETS TO GITHUB REPOSITORY"
echo "======================================================================"
echo "Now you need to add these secrets to your GitHub repository."
echo "Go to: $repo_settings_url"
echo ""

# List of secrets to create
secrets=(
  "SSH_PRIVATE_KEY:$ssh_private_key"
  "SSH_KNOWN_HOSTS:$ssh_known_hosts"
  "SERVER_HOST:$server_host"
  "SERVER_USER:$server_user"
  "DEPLOY_PATH:$deploy_path"
)

# For each secret, prompt to copy and add to GitHub
for secret in "${secrets[@]}"; do
  secret_name="${secret%%:*}"
  secret_value="${secret#*:}"
  
  echo "Secret: $secret_name"
  echo "1. Click 'New repository secret' on GitHub"
  echo "2. Enter the name: $secret_name"
  echo "3. Copy the value to clipboard and paste it into GitHub"
  echo -n "Ready to copy the value to clipboard? (y/n): "
  read -r copy_confirm
  
  if [[ $copy_confirm =~ ^[Yy]$ ]]; then
    copy_to_clipboard "$secret_value"
    echo "Value copied to clipboard for $secret_name"
    echo -n "Press Enter after adding this secret to GitHub..."
    read -r
  fi
done

# Step 8: Test connectivity (optional)
echo ""
echo "======================================================================"
echo "STEP 8: TEST SSH CONNECTIVITY"
echo "======================================================================"

echo -n "Do you want to test SSH connectivity to your server? (y/n): "
read -r test_ssh

if [[ $test_ssh =~ ^[Yy]$ ]]; then
  echo "Testing SSH connectivity to ${server_user}@${server_host}..."
  if ssh -i "$ssh_key_file" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "${server_user}@${server_host}" "echo 'SSH connection successful'"; then
    echo "✅ SSH connection test passed!"
    
    # Check if deploy path exists
    echo "Checking if deployment path exists..."
    if ssh -i "$ssh_key_file" "${server_user}@${server_host}" "[ -d \"$deploy_path\" ] && echo 'Directory exists' || echo 'Creating directory' && mkdir -p \"$deploy_path\""; then
      echo "✅ Deployment path check passed!"
    else
      echo "❌ Failed to check or create deployment path"
    fi
  else
    echo "❌ SSH connection test failed!"
    echo "   Please check your SSH configuration."
  fi
fi

# Final instructions
echo ""
echo "======================================================================"
echo "🎉 SETUP COMPLETE!"
echo "======================================================================"
echo "You have successfully set up the necessary GitHub repository secrets."
echo ""
echo "Next steps:"
echo "1. Make sure you've added all secrets to GitHub at:"
echo "   $repo_settings_url"
echo ""
echo "2. Update your GitHub Actions workflow file to use these secrets."
echo "   You can use the template in .github/workflows/3x-ui-workflow.yml"
echo ""
echo "3. Try running the workflow manually from the GitHub Actions tab"
echo ""
echo "For more information, see the README.md file."
echo "======================================================================" 