#!/bin/bash

# Security check script for 3x-ui VPN Service
# This script performs security audits and hardens the environment

# Source utilities
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
else
  echo -e "\033[0;31mError: utils.sh not found. Please ensure it exists in the scripts directory.\033[0m"
  exit 1
fi

log_message "🛡️ Starting security check and hardening process"

# Configuration variables
DEPLOY_PATH=${DEPLOY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}
COMPOSE_FILE="$DEPLOY_PATH/docker-compose.yml"
ENV_FILE="$DEPLOY_PATH/.env"
SESSION_TIMEOUT=1800  # in seconds (30 minutes)

# Function to check Docker Compose file for security issues
check_docker_compose() {
  log_message "🔍 Checking Docker Compose configuration..."
  
  local issues_found=0
  
  # Check if docker-compose file exists
  if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Docker Compose file not found at $COMPOSE_FILE"
    return 1
  fi
  
  # Check for privileged mode
  if grep -q "privileged: true" "$COMPOSE_FILE"; then
    log_warning "⚠️ Security risk: Container running in privileged mode"
    issues_found=$((issues_found + 1))
  else
    log_success "✅ No containers running in privileged mode"
  fi
  
  # Check for root user
  if grep -q "user: root" "$COMPOSE_FILE"; then
    log_warning "⚠️ Security risk: Container running as root user"
    issues_found=$((issues_found + 1))
  else
    log_success "✅ No containers explicitly set to run as root"
  fi
  
  # Check for volume mount security
  if grep -q "/:/host" "$COMPOSE_FILE" || grep -q "/:/rootfs" "$COMPOSE_FILE"; then
    log_warning "⚠️ Security risk: Container mounting root filesystem"
    issues_found=$((issues_found + 1))
  else
    log_success "✅ No containers mounting root filesystem"
  fi
  
  # Check for direct port exposures
  if grep -q "54321:54321" "$COMPOSE_FILE"; then
    log_warning "⚠️ Security note: Admin panel port (54321) directly exposed"
    issues_found=$((issues_found + 1))
  fi
  
  if [ $issues_found -eq 0 ]; then
    log_success "✅ Docker Compose configuration passed security checks"
    return 0
  else
    log_warning "⚠️ Found $issues_found security issues in Docker Compose configuration"
    return 1
  fi
}

# Function to check environment variables
check_environment() {
  log_message "🔍 Checking environment configuration..."
  
  local issues_found=0
  
  # Check if .env file exists (optional)
  if [ -f "$ENV_FILE" ]; then
    log_message "Analyzing .env file"
    
    # Check for default credentials
    if grep -q "XUI_USERNAME=admin" "$ENV_FILE" || grep -q "XUI_PASSWORD=admin" "$ENV_FILE"; then
      log_warning "⚠️ Security risk: Default admin credentials in use"
      issues_found=$((issues_found + 1))
    else
      log_success "✅ Custom admin credentials in use"
    fi
    
    # Check for JWT_SECRET
    if grep -q "JWT_SECRET=change_me_in_production" "$ENV_FILE"; then
      log_warning "⚠️ Security risk: Default JWT_SECRET in use"
      issues_found=$((issues_found + 1))
    else
      log_success "✅ Custom JWT_SECRET in use"
    fi
  else
    log_message "No .env file found, checking docker-compose.yml for environment variables"
    
    # Check docker-compose.yml for environment variables
    if grep -q "XUI_USERNAME: admin" "$COMPOSE_FILE" || grep -q "XUI_PASSWORD: admin" "$COMPOSE_FILE"; then
      log_warning "⚠️ Security risk: Default admin credentials in use"
      issues_found=$((issues_found + 1))
    else
      log_success "✅ Custom admin credentials in use"
    fi
    
    if grep -q "JWT_SECRET: change_me_in_production" "$COMPOSE_FILE"; then
      log_warning "⚠️ Security risk: Default JWT_SECRET in use"
      issues_found=$((issues_found + 1))
    else
      log_success "✅ Custom JWT_SECRET in use"
    fi
  fi
  
  # Check session timeout
  if ! grep -q "SESSION_TIMEOUT=$SESSION_TIMEOUT" "$COMPOSE_FILE" && ! grep -q "SESSION_TIMEOUT=$SESSION_TIMEOUT" "$ENV_FILE"; then
    log_warning "⚠️ Security recommendation: Session timeout not set or too long"
    log_message "  Adding SESSION_TIMEOUT=$SESSION_TIMEOUT to environment"
    # Add timeout to environment if absent
    if [ -f "$ENV_FILE" ]; then
      echo "SESSION_TIMEOUT=$SESSION_TIMEOUT" >> "$ENV_FILE"
    else
      log_message "  Could not add SESSION_TIMEOUT, no .env file found"
    fi
    issues_found=$((issues_found + 1))
  else
    log_success "✅ Session timeout properly configured"
  fi
  
  if [ $issues_found -eq 0 ]; then
    log_success "✅ Environment configuration passed security checks"
    return 0
  else
    log_warning "⚠️ Found $issues_found security issues in environment configuration"
    return 1
  fi
}

# Function to check certificate security
check_certificates() {
  log_message "🔍 Checking certificate security..."
  
  local domain=${DOMAIN:-"service.foodshare.club"}
  local cert_dir="$DEPLOY_PATH/cert/$domain"
  local cert_file="$cert_dir/fullchain.pem"
  
  if [ ! -f "$cert_file" ]; then
    log_warning "⚠️ No certificate found for $domain"
    return 1
  fi
  
  # Check certificate algorithm and key size
  local key_info=$(openssl x509 -in "$cert_file" -noout -text | grep "Public-Key:")
  local key_size=$(echo "$key_info" | grep -o "[0-9]\+ bit" | grep -o "[0-9]\+")
  
  if [ -z "$key_size" ]; then
    key_size=0  # Default to 0 if we couldn't parse the key size
  fi
  
  if [ "$key_size" -lt 2048 ]; then
    log_warning "⚠️ Weak key size: $key_size bits (should be at least 2048 bits)"
    return 1
  else
    log_success "✅ Strong key size: $key_size bits"
  fi
  
  # Check signature algorithm
  local sig_alg=$(openssl x509 -in "$cert_file" -noout -text | grep "Signature Algorithm" | head -1 | awk '{print $3}')
  if [[ "$sig_alg" == *"sha1"* ]]; then
    log_warning "⚠️ Weak signature algorithm: $sig_alg"
    return 1
  else
    log_success "✅ Strong signature algorithm: $sig_alg"
  fi
  
  # Check certificate expiration
  local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
  local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s)
  local current_epoch=$(date +%s)
  local days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))
  
  if [ "$days_remaining" -lt 30 ]; then
    log_warning "⚠️ Certificate for $domain expires in $days_remaining days"
    return 1
  else
    log_success "✅ Certificate for $domain valid for $days_remaining days"
  fi
  
  # Check file permissions
  local key_file="$cert_dir/privkey.pem"
  local key_perms=$(stat -c "%a" "$key_file" 2>/dev/null || stat -f "%Lp" "$key_file")
  local cert_perms=$(stat -c "%a" "$cert_file" 2>/dev/null || stat -f "%Lp" "$cert_file")
  
  if [ "$key_perms" != "600" ]; then
    log_warning "⚠️ Insecure private key permissions: $key_perms (should be 600)"
    chmod 600 "$key_file"
    log_message "  Fixed private key permissions"
  else
    log_success "✅ Private key has secure permissions"
  fi
  
  if [ "$cert_perms" != "644" ]; then
    log_warning "⚠️ Incorrect certificate permissions: $cert_perms (should be 644)"
    chmod 644 "$cert_file"
    log_message "  Fixed certificate permissions"
  else
    log_success "✅ Certificate has correct permissions"
  fi
  
  return 0
}

# Function to check XRay configuration security
check_xray_config() {
  log_message "🔍 Checking XRay configuration security..."
  
  local issues_found=0
  local db_dir="$DEPLOY_PATH/db"
  local x_ui_db="$db_dir/x-ui.db"
  
  # Check if database exists
  if [ ! -f "$x_ui_db" ]; then
    log_warning "⚠️ Database file not found: $x_ui_db"
    return 1
  fi
  
  # Check database permissions
  local db_perms=$(stat -c "%a" "$x_ui_db" 2>/dev/null || stat -f "%Lp" "$x_ui_db")
  if [ "$db_perms" != "600" ] && [ "$db_perms" != "644" ]; then
    log_warning "⚠️ Insecure database file permissions: $db_perms (should be 600 or 644)"
    chmod 600 "$x_ui_db"
    log_message "  Fixed database file permissions"
    issues_found=$((issues_found + 1))
  else
    log_success "✅ Database has secure permissions"
  fi
  
  # We can't easily check the XRay config directly, so we'll check environment variables
  # that affect security
  
  # Check if XRAY_VMESS_AEAD_FORCED is enabled
  if grep -q "XRAY_VMESS_AEAD_FORCED=false" "$COMPOSE_FILE" || 
     ([ -f "$ENV_FILE" ] && grep -q "XRAY_VMESS_AEAD_FORCED=false" "$ENV_FILE"); then
    log_warning "⚠️ Security recommendation: VMESS AEAD not enforced"
    issues_found=$((issues_found + 1))
  else
    log_success "✅ VMESS AEAD enforcement configured properly"
  fi
  
  if [ $issues_found -eq 0 ]; then
    log_success "✅ XRay configuration passed security checks"
    return 0
  else
    log_warning "⚠️ Found $issues_found security issues in XRay configuration"
    return 1
  fi
}

# Function to apply security recommendations
apply_security_fixes() {
  log_message "🔧 Applying security recommendations..."
  
  # Securely generate a new JWT secret if needed
  if grep -q "JWT_SECRET=change_me_in_production" "$ENV_FILE" 2>/dev/null || 
     grep -q "JWT_SECRET: change_me_in_production" "$COMPOSE_FILE"; then
    local new_jwt_secret=$(openssl rand -hex 32)
    log_message "  Generating new JWT_SECRET"
    
    if [ -f "$ENV_FILE" ]; then
      # Update .env file
      sed -i.bak "s|JWT_SECRET=.*|JWT_SECRET=$new_jwt_secret|g" "$ENV_FILE"
      rm -f "$ENV_FILE.bak"
    else
      # Update docker-compose.yml
      sed -i.bak "s|JWT_SECRET:.*|JWT_SECRET: $new_jwt_secret|g" "$COMPOSE_FILE"
      rm -f "$COMPOSE_FILE.bak"
    fi
    log_success "  Updated JWT_SECRET with a strong random value"
  fi
  
  # Enable VMESS AEAD enforcement
  if grep -q "XRAY_VMESS_AEAD_FORCED=false" "$ENV_FILE" 2>/dev/null; then
    sed -i.bak "s|XRAY_VMESS_AEAD_FORCED=false|XRAY_VMESS_AEAD_FORCED=true|g" "$ENV_FILE"
    rm -f "$ENV_FILE.bak"
    log_success "  Enabled VMESS AEAD enforcement in .env file"
  elif grep -q "XRAY_VMESS_AEAD_FORCED: false" "$COMPOSE_FILE"; then
    sed -i.bak "s|XRAY_VMESS_AEAD_FORCED: false|XRAY_VMESS_AEAD_FORCED: true|g" "$COMPOSE_FILE"
    rm -f "$COMPOSE_FILE.bak"
    log_success "  Enabled VMESS AEAD enforcement in docker-compose.yml"
  fi
  
  # Apply file permissions
  log_message "  Securing file permissions..."
  
  # Secure database directory
  chmod 700 "$DEPLOY_PATH/db"
  find "$DEPLOY_PATH/db" -type f -name "*.db" -exec chmod 600 {} \;
  log_success "  Secured database directory and files"
  
  # Secure certificate directory
  find "$DEPLOY_PATH/cert" -type d -exec chmod 700 {} \;
  find "$DEPLOY_PATH/cert" -type f -name "*.pem" -not -name "fullchain.pem" -exec chmod 600 {} \;
  find "$DEPLOY_PATH/cert" -type f -name "fullchain.pem" -exec chmod 644 {} \;
  log_success "  Secured certificate directory and files"
  
  log_success "✅ Security recommendations applied"
}

# Function to recommend system-level hardening
recommend_system_hardening() {
  log_message "📋 System hardening recommendations:"
  echo ""
  echo -e "${YELLOW}Recommended kernel parameters for security and performance:${NC}"
  echo -e "${BLUE}# Add to /etc/sysctl.conf${NC}"
  echo "fs.file-max = 1000000"
  echo "net.core.rmem_max = 67108864"
  echo "net.core.wmem_max = 67108864"
  echo "net.ipv4.tcp_rmem = 4096 87380 33554432"
  echo "net.ipv4.tcp_wmem = 4096 65536 33554432"
  echo "net.ipv4.tcp_congestion_control = bbr"
  echo "net.core.netdev_max_backlog = 30000"
  echo "net.core.somaxconn = 65535"
  echo "net.ipv4.tcp_max_syn_backlog = 8192"
  echo "net.ipv4.ip_local_port_range = 1024 65535"
  echo "net.ipv4.tcp_rfc1337 = 1"
  echo ""
  echo -e "${YELLOW}Firewall recommendations:${NC}"
  echo -e "${BLUE}# Only allow necessary ports${NC}"
  echo "ufw default deny incoming"
  echo "ufw default allow outgoing"
  echo "ufw allow 22/tcp      # SSH"
  echo "ufw allow 80/tcp      # HTTP"
  echo "ufw allow 443/tcp     # HTTPS"
  echo "ufw allow 54321/tcp   # 3x-ui admin panel"
  echo "# Add additional VPN ports as needed"
  echo ""
  echo -e "${YELLOW}Additional security tools to consider:${NC}"
  echo "- fail2ban: Protect against brute force attacks"
  echo "- unattended-upgrades: Automatic security updates"
  echo "- auditd: System auditing"
  echo "- ClamAV: Malware scanning"
  echo ""
}

# Main execution
main() {
  log_message "🛡️ Running comprehensive security check"
  
  # Check components
  check_docker_compose
  check_environment
  check_certificates
  check_xray_config
  
  # Apply fixes
  apply_security_fixes
  
  # Provide system recommendations
  recommend_system_hardening
}

# Execute main function
main

log_message "✅ Security check and hardening process completed"
exit 0 