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

# Parse arguments
GITHUB_TOKEN=""
ADD_TO_GITHUB=false
ADD_TO_SECRETS=false
ACCESS_TOKEN=""
TITLE="GitHub Actions Deploy Key"
ALLOW_WRITE=true
SKIP_PROMPT=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -t|--token)
      GITHUB_TOKEN="$2"
      shift 2
      ;;
    -a|--add-to-github)
      ADD_TO_GITHUB=true
      shift
      ;;
    -s|--add-to-secrets)
      ADD_TO_SECRETS=true
      shift
      ;;
    -w|--write-access)
      ALLOW_WRITE="$2"
      shift 2
      ;;
    --title)
      TITLE="$2"
      shift 2
      ;;
    -y|--yes)
      SKIP_PROMPT=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  -t, --token TOKEN        GitHub personal access token with repo permissions"
      echo "  -a, --add-to-github      Add the key to GitHub repository"
      echo "  -s, --add-to-secrets     Add the key to GitHub secrets"
      echo "  -w, --write-access BOOL  Allow write access (true/false)"
      echo "  --title TITLE            Title for the deploy key"
      echo "  -y, --yes                Skip all prompts and use defaults"
      echo "  -h, --help               Show this help message"
      echo ""
      exit 0
      ;;
    *)
      log_error "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

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

# Check if we have curl installed
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not found. Please install curl and try again."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_warning "jq is not found. Continuing without pretty JSON formatting."
    fi
}

# Add deploy key to GitHub
add_to_github() {
    local token="$1"
    local key_title="$2"
    local allow_write="$3"
    local public_key=$(cat "$KEY_DIR/github_deploy_key.pub")

    # Extract the key content without the type and comment
    local key_content=$(echo "$public_key" | awk '{print $2}')

    log_message "Adding deploy key to GitHub repository..."

    # Prepare JSON payload
    local DATA=$(cat <<EOF
{
  "title": "$key_title",
  "key": "$key_content",
  "read_only": $([ "$allow_write" = true ] && echo "false" || echo "true")
}
EOF
)

    # Make API request
    local response=$(curl -s -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: token $token" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -d "$DATA" \
        "https://api.github.com/repos/$REPO_NAME/keys")

    # Check response
    if echo "$response" | grep -q '"id":'; then
        local key_id=$(echo "$response" | grep -o '"id": [0-9]*' | head -1 | awk '{print $2}')
        log_success "Deploy key added successfully! (ID: $key_id)"
    else
        log_error "Failed to add deploy key. GitHub response:"
        if command -v jq &> /dev/null; then
            echo "$response" | jq .
        else
            echo "$response"
        fi
        exit 1
    fi
}

# Add private key to GitHub secrets
add_to_secrets() {
    local token="$1"
    local private_key=$(cat "$KEY_DIR/github_deploy_key" | base64)

    log_message "Adding private key to GitHub secrets..."

    # Get public key for secret encryption
    local public_key_response=$(curl -s -X GET \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: token $token" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$REPO_NAME/actions/secrets/public-key")

    # Extract key and key_id
    local public_key=$(echo "$public_key_response" | grep -o '"key": "[^"]*' | head -1 | cut -d '"' -f 4)
    local key_id=$(echo "$public_key_response" | grep -o '"key_id": "[^"]*' | head -1 | cut -d '"' -f 4)

    if [ -z "$public_key" ] || [ -z "$key_id" ]; then
        log_error "Failed to get public key for secret encryption"
        exit 1
    fi

    # Encrypt the secret
    # Note: This requires sodium-plus or similar, which is complex for a bash script
    # For simplicity, we'll guide users to add it manually

    log_warning "Adding encrypted secrets via API requires more complex encryption."
    log_message "Please add the private key manually to your GitHub secrets:"
    log_message "   1. Go to https://github.com/$REPO_NAME/settings/secrets/actions"
    log_message "   2. Click 'New repository secret'"
    log_message "   3. Name: DEPLOY_KEY"
    log_message "   4. Value: (copy the private key below)"
    log_message "   5. Click 'Add secret'"

    return 1
}

# Display instructions for adding the key to GitHub
display_instructions() {
    log_message "\n${YELLOW}==== NEXT STEPS ====${NC}"

    if [ "$ADD_TO_GITHUB" = false ]; then
        log_message "1. Add this public key to your GitHub repository as a deploy key:"
        log_message "   - Go to https://github.com/$REPO_NAME/settings/keys"
        log_message "   - Click 'Add deploy key'"
        log_message "   - Title: $TITLE"
        log_message "   - Key: (paste the public key below)"
        log_message "   - Check 'Allow write access' if needed for deployments"
        log_message "   - Click 'Add key'"
    fi

    if [ "$ADD_TO_SECRETS" = false ]; then
        log_message "\n2. Add the private key as a GitHub secret:"
        log_message "   - Go to https://github.com/$REPO_NAME/settings/secrets/actions"
        log_message "   - Click 'New repository secret'"
        log_message "   - Name: DEPLOY_KEY"
        log_message "   - Value: (paste the private key below)"
        log_message "   - Click 'Add secret'"
    fi

    log_message "\n3. Update your GitHub Actions workflow to use this key:"
    log_message "   uses: webfactory/ssh-agent@v0.7.0"
    log_message "   with:"
    log_message "     ssh-private-key: \${{ secrets.DEPLOY_KEY }}"
    log_message "     log-public-key: true"
}

# Main execution
main() {
    log_message "🔑 GitHub Deploy Key Setup"
    log_message "====================\n"

    check_dependencies

    # Check if key already exists
    if [ -f "$KEY_DIR/github_deploy_key" ]; then
        if [ "$SKIP_PROMPT" = true ]; then
            generate_key
        else
            log_warning "SSH key already exists at $KEY_DIR/github_deploy_key"
            read -p "Do you want to overwrite it? (y/n): " overwrite
            if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                generate_key
            else
                log_message "Using existing key."
            fi
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

    # Add key to GitHub if requested
    if [ "$ADD_TO_GITHUB" = true ]; then
        if [ -z "$GITHUB_TOKEN" ]; then
            log_error "GitHub token is required to add the key to GitHub"
            read -p "Enter your GitHub personal access token: " GITHUB_TOKEN
        fi

        if [ -n "$GITHUB_TOKEN" ]; then
            add_to_github "$GITHUB_TOKEN" "$TITLE" "$ALLOW_WRITE"
        else
            log_error "No GitHub token provided. Skipping adding to GitHub."
            ADD_TO_GITHUB=false
        fi
    fi

    # Add key to GitHub secrets if requested
    if [ "$ADD_TO_SECRETS" = true ]; then
        if [ -z "$GITHUB_TOKEN" ]; then
            log_error "GitHub token is required to add the key to GitHub secrets"
            read -p "Enter your GitHub personal access token: " GITHUB_TOKEN
        fi

        if [ -n "$GITHUB_TOKEN" ]; then
            add_to_secrets "$GITHUB_TOKEN"
        else
            log_error "No GitHub token provided. Skipping adding to GitHub secrets."
            ADD_TO_SECRETS=false
        fi
    fi

    # Display instructions
    display_instructions

    log_message "\n${GREEN}Deploy key setup complete!${NC}"
}

# Execute the main function
main