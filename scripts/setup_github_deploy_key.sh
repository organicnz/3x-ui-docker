#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_message() { echo "$1"; }

# Directory for key generation
KEY_DIR="$HOME/.ssh/github_keys"
REPO_NAME="organicnz/3x-ui-docker"
KEY_COMMENT="git@github.com:$REPO_NAME.git"

# Create directory if it doesn't exist
mkdir -p "$KEY_DIR"

# Generate SSH key with GitHub URL pattern in comment
generate_key() {
    log_message "Generating new SSH key for GitHub deploy key..."
    ssh-keygen -t rsa -b 3072 -C "$KEY_COMMENT" -f "$KEY_DIR/github_deploy_key" -N ""
    
    if [ $? -eq 0 ]; then
        log_success "SSH key generated successfully!"
    else
        log_error "Failed to generate SSH key"
        exit 1
    fi
}

# Display instructions for adding the key to GitHub
instructions() {
    log_message "\n${YELLOW}==== NEXT STEPS ====${NC}"
    log_message "1. Add this public key to your GitHub repository as a deploy key:"
    log_message "   - Go to https://github.com/$REPO_NAME/settings/keys"
    log_message "   - Click 'Add deploy key'"
    log_message "   - Title: GitHub Actions Deploy Key"
    log_message "   - Key: (paste the public key below)"
    log_message "   - Check 'Allow write access' if needed for deployments"
    log_message "   - Click 'Add key'"
    log_message "\n2. Update your GitHub Actions workflow to use this key:"
    log_message "   uses: webfactory/ssh-agent@v0.7.0"
    log_message "   with:"
    log_message "     ssh-private-key: \${{ secrets.DEPLOY_KEY }}"
    log_message "     log-public-key: true"
    log_message "\n3. Add the private key as a GitHub secret:"
    log_message "   - Go to https://github.com/$REPO_NAME/settings/secrets/actions"
    log_message "   - Click 'New repository secret'"
    log_message "   - Name: DEPLOY_KEY"
    log_message "   - Value: (paste the private key below)"
    log_message "   - Click 'Add secret'"
}

# Main execution
main() {
    log_message "🔑 GitHub Deploy Key Setup"
    log_message "====================\n"
    
    # Check if key already exists
    if [ -f "$KEY_DIR/github_deploy_key" ]; then
        log_warning "SSH key already exists at $KEY_DIR/github_deploy_key"
        read -p "Do you want to overwrite it? (y/n): " overwrite
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            generate_key
        else
            log_message "Using existing key."
        fi
    else
        generate_key
    fi
    
    # Display the public key
    log_message "\n${GREEN}=== PUBLIC KEY ===${NC}"
    cat "$KEY_DIR/github_deploy_key.pub"
    
    # Display the private key
    log_message "\n${YELLOW}=== PRIVATE KEY (Add this as a GitHub secret) ===${NC}"
    cat "$KEY_DIR/github_deploy_key"
    
    # Display instructions
    instructions
    
    log_message "\n${GREEN}Deploy key setup complete!${NC}"
}

# Execute the main function
main 