#!/bin/bash

# Source utilities if available
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
  use_colors=true
else
  # Define minimal color functions if utils.sh is not available
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  NC='\033[0m' # No Color
  
  log_success() { echo -e "${GREEN}✅ $1${NC}"; }
  log_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
  log_error() { echo -e "${RED}❌ $1${NC}"; }
  log_message() { echo -e "$1"; }
  
  use_colors=true
fi

# Parse command line arguments
non_interactive=false
update_env=false
update_compose=false
show_help=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help=true
      shift
      ;;
    -y|--yes)
      non_interactive=true
      update_env=true
      update_compose=true
      shift
      ;;
    --env-only)
      non_interactive=true
      update_env=true
      shift
      ;;
    --compose-only)
      non_interactive=true
      update_compose=true
      shift
      ;;
    *)
      log_error "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Display help
if [ "$show_help" = true ]; then
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help        Show this help message"
  echo "  -y, --yes         Update both .env and docker-compose.yml files without prompting"
  echo "  --env-only        Update only the .env file without prompting"
  echo "  --compose-only    Update only the docker-compose.yml file without prompting"
  echo ""
  echo "Examples:"
  echo "  $0                Interactive mode, will prompt for confirmation"
  echo "  $0 -y             Non-interactive mode, updates both files"
  echo "  $0 --env-only     Only update the .env file"
  echo ""
  exit 0
fi

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
  log_error "openssl is required but not found. Please install it and try again."
  exit 1
fi

# Generate a secure random JWT secret
generate_jwt_secret() {
  openssl rand -hex 32
}

# Update JWT_SECRET in .env file
update_env_file() {
  local new_secret="$1"
  local env_file=".env"
  
  # Check if .env file exists
  if [ -f "$env_file" ]; then
    # Create backup
    cp "$env_file" "${env_file}.bak"
    log_message "Created backup of .env file at ${env_file}.bak"
    
    # Check if JWT_SECRET exists in the file
    if grep -q "JWT_SECRET=" "$env_file"; then
      # Update existing JWT_SECRET
      sed -i.tmp "s|JWT_SECRET=.*|JWT_SECRET=$new_secret|g" "$env_file"
      rm -f "${env_file}.tmp"
      log_success "Updated JWT_SECRET in .env file"
    else
      # Add JWT_SECRET to .env file
      echo "JWT_SECRET=$new_secret" >> "$env_file"
      log_success "Added JWT_SECRET to .env file"
    fi
  else
    # Create new .env file if it doesn't exist
    echo "JWT_SECRET=$new_secret" > "$env_file"
    log_success "Created new .env file with JWT_SECRET"
    
    log_warning "You may need to add other environment variables to the .env file"
  fi
}

# Update JWT_SECRET in docker-compose.yml
update_compose_file() {
  local new_secret="$1"
  local compose_file="docker-compose.yml"
  
  # Check if docker-compose.yml file exists
  if [ -f "$compose_file" ]; then
    # Create backup
    cp "$compose_file" "${compose_file}.bak"
    log_message "Created backup of docker-compose.yml file at ${compose_file}.bak"
    
    # Check if JWT_SECRET exists in the file
    if grep -q "JWT_SECRET:" "$compose_file"; then
      # Update existing JWT_SECRET
      sed -i.tmp "s|JWT_SECRET:.*|JWT_SECRET: $new_secret|g" "$compose_file"
      rm -f "${compose_file}.tmp"
      log_success "Updated JWT_SECRET in docker-compose.yml file"
    else
      log_warning "Could not find JWT_SECRET in docker-compose.yml to update"
      log_warning "You may need to update the docker-compose.yml file manually"
    fi
  else
    log_error "docker-compose.yml file not found"
    exit 1
  fi
}

# Main function
main() {
  log_message "🔑 Generating a secure JWT_SECRET..."
  
  # Generate new JWT secret
  new_jwt_secret=$(generate_jwt_secret)
  log_success "Generated new JWT_SECRET: $new_jwt_secret"
  
  if [ "$non_interactive" = false ]; then
    # Interactive mode - ask for confirmation
    read -p "Do you want to update the .env file with this new secret? (y/n): " env_response
    if [[ "$env_response" =~ ^[Yy]$ ]]; then
      update_env=true
    fi
    
    read -p "Do you want to update the docker-compose.yml file with this new secret? (y/n): " compose_response
    if [[ "$compose_response" =~ ^[Yy]$ ]]; then
      update_compose=true
    fi
  fi
  
  # Update files based on flags
  if [ "$update_env" = true ]; then
    update_env_file "$new_jwt_secret"
  fi
  
  if [ "$update_compose" = true ]; then
    update_compose_file "$new_jwt_secret"
  fi
  
  if [ "$update_env" = false ] && [ "$update_compose" = false ]; then
    log_message "No files were updated. You can manually add this JWT_SECRET to your configuration."
  else
    log_message ""
    log_message "🔒 JWT_SECRET updated successfully!"
    log_message "ℹ️ Remember to restart your services for the changes to take effect:"
    log_message "   docker-compose down && docker-compose up -d"
  fi
  
  log_message ""
}

# Execute main function
main 