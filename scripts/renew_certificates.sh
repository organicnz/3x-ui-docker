#!/bin/bash

# Certificate renewal and validation script
# This script automates the process of checking, renewing, and validating SSL certificates

# Source utilities
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
else
  echo -e "\033[0;31mError: utils.sh not found. Please ensure it exists in the scripts directory.\033[0m"
  exit 1
fi

log_message "🔍 Starting certificate validation and renewal process"

# Configuration variables
DEPLOY_PATH=${DEPLOY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}
DOMAIN=${DOMAIN:-"service.foodshare.club"}
CERT_DIR="$DEPLOY_PATH/cert/$DOMAIN"
TEMP_CERT_DIR="$DEPLOY_PATH/temp_cert"
DAYS_THRESHOLD=15  # Renew if less than X days remaining

# Create directories if they don't exist
mkdir -p "$CERT_DIR"
mkdir -p "$TEMP_CERT_DIR"

# Function to check certificate expiration
check_certificate() {
  local cert_file="$1"
  
  if [ ! -f "$cert_file" ]; then
    log_error "Certificate file not found: $cert_file"
    return 1
  fi
  
  # Get expiration date
  local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
  local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s)
  local current_epoch=$(date +%s)
  local seconds_remaining=$((expiry_epoch - current_epoch))
  local days_remaining=$((seconds_remaining / 86400))
  
  log_message "Certificate will expire in $days_remaining days"
  
  if [ $days_remaining -lt $DAYS_THRESHOLD ]; then
    return 0  # Certificate needs renewal
  else
    return 1  # Certificate is still valid
  fi
}

# Function to generate a self-signed certificate
generate_self_signed() {
  log_message "🔑 Generating self-signed certificate for $DOMAIN"
  
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$TEMP_CERT_DIR/privkey.pem" \
    -out "$TEMP_CERT_DIR/fullchain.pem" \
    -subj "/CN=$DOMAIN/O=3x-ui/C=US" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:www.$DOMAIN"
    
  # Validate the new certificate
  if openssl x509 -noout -text -in "$TEMP_CERT_DIR/fullchain.pem" > /dev/null; then
    log_success "Self-signed certificate generated successfully"
    # Copy to the certificate directory
    cp "$TEMP_CERT_DIR/privkey.pem" "$CERT_DIR/privkey.pem"
    cp "$TEMP_CERT_DIR/fullchain.pem" "$CERT_DIR/fullchain.pem"
    chmod 600 "$CERT_DIR/privkey.pem"
    chmod 644 "$CERT_DIR/fullchain.pem"
    return 0
  else
    log_error "Failed to generate self-signed certificate"
    return 1
  fi
}

# Function to verify certificate installation
verify_certificate() {
  log_message "🔍 Verifying certificate for $DOMAIN"
  
  # Display certificate information
  log_message "Certificate Details:"
  openssl x509 -noout -text -in "$CERT_DIR/fullchain.pem" | grep -E "Subject:|Issuer:|Not Before:|Not After :|DNS:"
  
  # Verify certificate and key match
  cert_modulus=$(openssl x509 -noout -modulus -in "$CERT_DIR/fullchain.pem" | md5sum)
  key_modulus=$(openssl rsa -noout -modulus -in "$CERT_DIR/privkey.pem" | md5sum)
  
  if [ "$cert_modulus" = "$key_modulus" ]; then
    log_success "Certificate and private key match."
    return 0
  else
    log_error "Certificate and private key do NOT match!"
    return 1
  fi
}

# Function to restart the service
restart_service() {
  log_message "🔄 Restarting 3x-ui service to apply new certificate"
  cd "$DEPLOY_PATH"
  docker-compose restart 3x-ui
  log_success "Service restarted"
}

# Main execution
main() {
  log_message "🔑 Certificate check for domain: $DOMAIN"
  
  # Check if certificate exists
  if [ -f "$CERT_DIR/fullchain.pem" ]; then
    log_message "Existing certificate found, checking expiration..."
    if check_certificate "$CERT_DIR/fullchain.pem"; then
      log_warning "Certificate is expiring soon, renewing..."
      generate_self_signed
      if [ $? -eq 0 ]; then
        verify_certificate
        restart_service
      fi
    else
      log_success "Certificate is still valid."
      verify_certificate
    fi
  else
    log_warning "No existing certificate found, generating new one..."
    generate_self_signed
    if [ $? -eq 0 ]; then
      verify_certificate
      restart_service
    fi
  fi
}

# Execute main function
main

log_message "✅ Certificate validation and renewal process completed"
exit 0 