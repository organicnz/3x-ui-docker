#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==== 3x-ui VPN GitHub Secrets Setup ====${NC}"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}GitHub CLI (gh) is not installed. Please install it first:${NC}"
    echo -e "macOS: ${YELLOW}brew install gh${NC}"
    echo -e "Linux: ${YELLOW}https://github.com/cli/cli/blob/trunk/docs/install_linux.md${NC}"
    exit 1
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}You need to login to GitHub CLI first${NC}"
    gh auth login
fi

# Get repository name
REPO_URL=$(git config --get remote.origin.url)
if [ -z "$REPO_URL" ]; then
    echo -e "${RED}Unable to detect GitHub repository.${NC}"
    echo -e "${YELLOW}Please enter your GitHub repository in format 'owner/repo':${NC}"
    read REPO
else
    # Extract owner/repo from git URL
    if [[ $REPO_URL == *"github.com"* ]]; then
        REPO=$(echo $REPO_URL | sed -n 's/.*github.com[:/]\(.*\)\.git.*/\1/p')
        if [ -z "$REPO" ]; then
            REPO=$(echo $REPO_URL | sed -n 's/.*github.com[:/]\(.*\).*/\1/p')
        fi
    fi
    
    if [ -z "$REPO" ]; then
        echo -e "${RED}Unable to parse repository from git URL:${NC} $REPO_URL"
        echo -e "${YELLOW}Please enter your GitHub repository in format 'owner/repo':${NC}"
        read REPO
    fi
fi

echo -e "${BLUE}Working with repository:${NC} $REPO"

# Define required secrets
declare -A REQUIRED_SECRETS
REQUIRED_SECRETS=(
    ["SSH_PRIVATE_KEY"]="Your SSH private key for server access"
    ["SSH_KNOWN_HOSTS"]="SSH known hosts entry (output of ssh-keyscan for your server)"
    ["SERVER_HOST"]="Hostname or IP address of your server (e.g., 64.227.113.96)"
    ["SERVER_USER"]="SSH username for server access (e.g., organic)"
    ["DEPLOY_PATH"]="Path on the server for deployment (e.g., /home/organic/dev/3x-ui)"
    ["VPN_DOMAIN"]="Your domain name (e.g., service.foodshare.club)"
    ["PANEL_PATH"]="Admin panel access path (e.g., BXv8SI7gBe)"
    ["XUI_USERNAME"]="Username for 3x-ui panel (e.g., organic)"
    ["XUI_PASSWORD"]="Password for 3x-ui panel"
    ["JWT_SECRET"]="Secret for JWT token signing"
    ["ADMIN_EMAIL"]="Admin email address (e.g., admin@example.com)"
    ["XRAY_VMESS_AEAD_FORCED"]="XRay VMESS AEAD forced setting (e.g., false)"
)

# Get existing secrets
echo -e "${BLUE}Checking existing secrets...${NC}"
EXISTING_SECRETS=$(gh secret list -R $REPO --json name -q '.[].name' 2>/dev/null)

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to retrieve existing secrets. Check your GitHub authentication.${NC}"
    exit 1
fi

# Convert to array for easier searching
readarray -t EXISTING_SECRETS_ARRAY <<< "$EXISTING_SECRETS"

echo -e "${GREEN}Found ${#EXISTING_SECRETS_ARRAY[@]} existing secrets${NC}"

# Check which secrets are missing
echo -e "${BLUE}Checking for missing secrets...${NC}"
MISSING_SECRETS=()

for SECRET_NAME in "${!REQUIRED_SECRETS[@]}"; do
    if [[ ! " ${EXISTING_SECRETS_ARRAY[*]} " =~ " ${SECRET_NAME} " ]]; then
        MISSING_SECRETS+=("$SECRET_NAME")
    else
        echo -e "${GREEN}✓ ${SECRET_NAME} already set${NC}"
    fi
done

# Check for .env file to pre-populate values
if [ -f ".env" ]; then
    echo -e "${BLUE}Found .env file. Will use for default values.${NC}"
    source <(grep -v '^#' .env | sed 's/^/export /')
fi

# Check for .env.local file to pre-populate values (has precedence over .env)
if [ -f ".env.local" ]; then
    echo -e "${BLUE}Found .env.local file. Will use for default values (overrides .env).${NC}"
    source <(grep -v '^#' .env.local | sed 's/^/export /')
fi

# Setup missing secrets
if [ ${#MISSING_SECRETS[@]} -eq 0 ]; then
    echo -e "${GREEN}All required secrets are already set up!${NC}"
else
    echo -e "${YELLOW}Found ${#MISSING_SECRETS[@]} missing secrets that need to be set up:${NC}"
    
    for SECRET_NAME in "${MISSING_SECRETS[@]}"; do
        echo -e "${BLUE}Setting up:${NC} $SECRET_NAME - ${REQUIRED_SECRETS[$SECRET_NAME]}"
        
        SECRET_VALUE=""
        
        # Try to get default value from environment variables
        DEFAULT_VALUE=${!SECRET_NAME}
        
        # Special handling for certain secrets
        case "$SECRET_NAME" in
            SSH_PRIVATE_KEY)
                if [ -z "$DEFAULT_VALUE" ]; then
                    # Suggest default SSH key path
                    DEFAULT_SSH_KEY="$HOME/.ssh/id_rsa"
                    echo -e "${YELLOW}Enter path to SSH private key file [default: $DEFAULT_SSH_KEY]:${NC}"
                    read SSH_KEY_PATH
                    
                    if [ -z "$SSH_KEY_PATH" ]; then
                        SSH_KEY_PATH="$DEFAULT_SSH_KEY"
                    fi
                    
                    if [ -f "$SSH_KEY_PATH" ]; then
                        SECRET_VALUE=$(cat "$SSH_KEY_PATH")
                        echo -e "${GREEN}Using SSH key from:${NC} $SSH_KEY_PATH"
                    else
                        echo -e "${RED}SSH key file not found:${NC} $SSH_KEY_PATH"
                        echo -e "${YELLOW}Enter SSH private key directly (paste and press Enter, then Ctrl+D):${NC}"
                        SECRET_VALUE=$(cat)
                    fi
                else
                    SECRET_VALUE="$DEFAULT_VALUE"
                    echo -e "${GREEN}Using SSH key from environment variable${NC}"
                fi
                ;;
                
            SSH_KNOWN_HOSTS)
                if [ -z "$DEFAULT_VALUE" ]; then
                    # If SERVER_HOST is set, use it to generate known_hosts
                    if [ ! -z "$SERVER_HOST" ]; then
                        echo -e "${YELLOW}Generating SSH known_hosts for $SERVER_HOST...${NC}"
                        KNOWN_HOSTS=$(ssh-keyscan -H "$SERVER_HOST" 2>/dev/null)
                        
                        if [ ! -z "$KNOWN_HOSTS" ]; then
                            SECRET_VALUE="$KNOWN_HOSTS"
                            echo -e "${GREEN}Generated known_hosts entry.${NC}"
                        else
                            echo -e "${RED}Failed to generate known_hosts entry.${NC}"
                            echo -e "${YELLOW}Enter SSH known_hosts manually (paste and press Enter, then Ctrl+D):${NC}"
                            SECRET_VALUE=$(cat)
                        fi
                    else
                        echo -e "${YELLOW}Enter SSH known_hosts (paste and press Enter, then Ctrl+D):${NC}"
                        SECRET_VALUE=$(cat)
                    fi
                else
                    SECRET_VALUE="$DEFAULT_VALUE"
                    echo -e "${GREEN}Using known_hosts from environment variable${NC}"
                fi
                ;;
                
            *)
                # For other secrets, use default if available, otherwise prompt
                if [ ! -z "$DEFAULT_VALUE" ]; then
                    echo -e "${YELLOW}Suggested value from environment:${NC} $DEFAULT_VALUE"
                    echo -e "${YELLOW}Press Enter to use this value or type a new one:${NC}"
                    read NEW_VALUE
                    
                    if [ -z "$NEW_VALUE" ]; then
                        SECRET_VALUE="$DEFAULT_VALUE"
                    else
                        SECRET_VALUE="$NEW_VALUE"
                    fi
                else
                    echo -e "${YELLOW}Enter value for $SECRET_NAME:${NC}"
                    if [[ "$SECRET_NAME" == *"PASSWORD"* || "$SECRET_NAME" == "JWT_SECRET" ]]; then
                        read -s SECRET_VALUE  # Hide sensitive input
                        echo  # Add a newline after hidden input
                    else
                        read SECRET_VALUE
                    fi
                fi
                ;;
        esac
        
        # Add secret to GitHub
        if [ ! -z "$SECRET_VALUE" ]; then
            echo -e "${BLUE}Adding secret ${SECRET_NAME} to GitHub repository...${NC}"
            echo "$SECRET_VALUE" | gh secret set "$SECRET_NAME" -R "$REPO"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Successfully added ${SECRET_NAME}${NC}"
            else
                echo -e "${RED}✗ Failed to add ${SECRET_NAME}${NC}"
            fi
        else
            echo -e "${RED}✗ No value provided for ${SECRET_NAME}, skipping${NC}"
        fi
        
        echo ""  # Add spacing between secrets
    done
fi

echo -e "${GREEN}GitHub secrets setup completed!${NC}"
echo -e "${BLUE}To verify, run:${NC} gh secret list -R $REPO" 