#!/bin/bash

# Automatic backup script for 3x-ui VPN Service
# This script creates regular backups of the database and certificates

# Source utilities
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
else
  echo -e "\033[0;31mError: utils.sh not found. Please ensure it exists in the scripts directory.\033[0m"
  exit 1
fi

log_message "💾 Starting backup process"

# Configuration variables
DEPLOY_PATH=${DEPLOY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}
BACKUP_DIR="$DEPLOY_PATH/backups"
DB_DIR="$DEPLOY_PATH/db"
CERT_DIR="$DEPLOY_PATH/cert"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}  # Keep backups for 7 days by default

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to backup the database
backup_database() {
  log_message "📊 Backing up database..."
  
  local db_file="$DB_DIR/x-ui.db"
  local backup_file="$BACKUP_DIR/x-ui.db.$TIMESTAMP.bak"
  
  if [ ! -f "$db_file" ]; then
    log_error "Database file not found at $db_file"
    return 1
  fi
  
  # Create a backup
  cp "$db_file" "$backup_file"
  
  if [ $? -eq 0 ]; then
    # Compress the backup
    gzip "$backup_file"
    
    if [ $? -eq 0 ]; then
      log_success "✅ Database backup created: $(basename "$backup_file").gz"
      return 0
    else
      log_error "Failed to compress database backup"
      return 1
    fi
  else
    log_error "Failed to create database backup"
    return 1
  fi
}

# Function to backup certificates
backup_certificates() {
  log_message "🔐 Backing up certificates..."
  
  local cert_backup_dir="$BACKUP_DIR/cert_$TIMESTAMP"
  
  # Create certificate backup directory
  mkdir -p "$cert_backup_dir"
  
  # Backup all certificate directories
  find "$CERT_DIR" -maxdepth 1 -type d -not -path "$CERT_DIR" | while read domain_dir; do
    domain=$(basename "$domain_dir")
    
    # Create domain directory in backup
    mkdir -p "$cert_backup_dir/$domain"
    
    # Copy certificate files
    if [ -f "$domain_dir/fullchain.pem" ] && [ -f "$domain_dir/privkey.pem" ]; then
      cp "$domain_dir/fullchain.pem" "$cert_backup_dir/$domain/"
      cp "$domain_dir/privkey.pem" "$cert_backup_dir/$domain/"
      log_success "✅ Certificates for $domain backed up"
    else
      log_warning "⚠️ No certificate files found for $domain"
    fi
  done
  
  # Compress the certificate backup
  tar -czf "$BACKUP_DIR/certificates_$TIMESTAMP.tar.gz" -C "$BACKUP_DIR" "cert_$TIMESTAMP"
  
  if [ $? -eq 0 ]; then
    # Remove the uncompressed directory
    rm -rf "$cert_backup_dir"
    log_success "✅ Certificate backup created: certificates_$TIMESTAMP.tar.gz"
    return 0
  else
    log_error "Failed to compress certificate backup"
    return 1
  fi
}

# Function to backup configuration files
backup_config() {
  log_message "⚙️ Backing up configuration files..."
  
  local config_backup_dir="$BACKUP_DIR/config_$TIMESTAMP"
  
  # Create config backup directory
  mkdir -p "$config_backup_dir"
  
  # Copy Docker Compose file
  cp "$DEPLOY_PATH/docker-compose.yml" "$config_backup_dir/"
  
  # Copy .env file if it exists
  if [ -f "$DEPLOY_PATH/.env" ]; then
    cp "$DEPLOY_PATH/.env" "$config_backup_dir/"
  fi
  
  # Copy Caddy configuration
  if [ -d "$DEPLOY_PATH/caddy_config" ]; then
    mkdir -p "$config_backup_dir/caddy_config"
    cp -r "$DEPLOY_PATH/caddy_config/Caddyfile" "$config_backup_dir/caddy_config/" 2>/dev/null
  fi
  
  # Compress the config backup
  tar -czf "$BACKUP_DIR/config_$TIMESTAMP.tar.gz" -C "$BACKUP_DIR" "config_$TIMESTAMP"
  
  if [ $? -eq 0 ]; then
    # Remove the uncompressed directory
    rm -rf "$config_backup_dir"
    log_success "✅ Configuration backup created: config_$TIMESTAMP.tar.gz"
    return 0
  else
    log_error "Failed to compress configuration backup"
    return 1
  fi
}

# Function to clean up old backups
cleanup_old_backups() {
  log_message "🧹 Cleaning up old backups..."
  
  local retention_seconds=$((BACKUP_RETENTION_DAYS * 24 * 60 * 60))
  local current_time=$(date +%s)
  
  # Find and remove old database backups
  find "$BACKUP_DIR" -name "x-ui.db.*.bak.gz" | while read backup_file; do
    # Extract timestamp from filename
    local timestamp_part=$(basename "$backup_file" | sed -E 's/x-ui\.db\.([0-9]{8}_[0-9]{6})\.bak\.gz/\1/')
    
    # Convert timestamp to epoch
    local backup_date=$(date -d "${timestamp_part:0:8} ${timestamp_part:9:2}:${timestamp_part:11:2}:${timestamp_part:13:2}" +%s 2>/dev/null || date -j -f "%Y%m%d_%H%M%S" "$timestamp_part" +%s)
    
    # Check if the backup is older than retention period
    if [ $((current_time - backup_date)) -gt $retention_seconds ]; then
      rm "$backup_file"
      log_message "  Removed old database backup: $(basename "$backup_file")"
    fi
  done
  
  # Find and remove old certificate backups
  find "$BACKUP_DIR" -name "certificates_*.tar.gz" | while read backup_file; do
    # Extract timestamp from filename
    local timestamp_part=$(basename "$backup_file" | sed -E 's/certificates_([0-9]{8}_[0-9]{6})\.tar\.gz/\1/')
    
    # Convert timestamp to epoch
    local backup_date=$(date -d "${timestamp_part:0:8} ${timestamp_part:9:2}:${timestamp_part:11:2}:${timestamp_part:13:2}" +%s 2>/dev/null || date -j -f "%Y%m%d_%H%M%S" "$timestamp_part" +%s)
    
    # Check if the backup is older than retention period
    if [ $((current_time - backup_date)) -gt $retention_seconds ]; then
      rm "$backup_file"
      log_message "  Removed old certificate backup: $(basename "$backup_file")"
    fi
  done
  
  # Find and remove old config backups
  find "$BACKUP_DIR" -name "config_*.tar.gz" | while read backup_file; do
    # Extract timestamp from filename
    local timestamp_part=$(basename "$backup_file" | sed -E 's/config_([0-9]{8}_[0-9]{6})\.tar\.gz/\1/')
    
    # Convert timestamp to epoch
    local backup_date=$(date -d "${timestamp_part:0:8} ${timestamp_part:9:2}:${timestamp_part:11:2}:${timestamp_part:13:2}" +%s 2>/dev/null || date -j -f "%Y%m%d_%H%M%S" "$timestamp_part" +%s)
    
    # Check if the backup is older than retention period
    if [ $((current_time - backup_date)) -gt $retention_seconds ]; then
      rm "$backup_file"
      log_message "  Removed old config backup: $(basename "$backup_file")"
    fi
  done
  
  log_success "✅ Backup cleanup completed"
}

# Function to create a full backup archive
create_full_backup() {
  log_message "📦 Creating full backup archive..."
  
  local full_backup_file="$BACKUP_DIR/full_backup_$TIMESTAMP.tar.gz"
  
  # Get list of backup files created in this run
  local db_backup=$(find "$BACKUP_DIR" -name "x-ui.db.$TIMESTAMP.bak.gz" -type f)
  local cert_backup=$(find "$BACKUP_DIR" -name "certificates_$TIMESTAMP.tar.gz" -type f)
  local config_backup=$(find "$BACKUP_DIR" -name "config_$TIMESTAMP.tar.gz" -type f)
  
  # Create a temporary directory for the full backup
  local temp_dir="$BACKUP_DIR/full_backup_temp_$TIMESTAMP"
  mkdir -p "$temp_dir"
  
  # Copy backup files to the temporary directory
  if [ -n "$db_backup" ]; then
    cp "$db_backup" "$temp_dir/"
  fi
  
  if [ -n "$cert_backup" ]; then
    cp "$cert_backup" "$temp_dir/"
  fi
  
  if [ -n "$config_backup" ]; then
    cp "$config_backup" "$temp_dir/"
  fi
  
  # Create a manifest file
  echo "3x-ui VPN Full Backup - $TIMESTAMP" > "$temp_dir/manifest.txt"
  echo "-----------------------------------" >> "$temp_dir/manifest.txt"
  echo "Created: $(date)" >> "$temp_dir/manifest.txt"
  echo "Retention period: $BACKUP_RETENTION_DAYS days" >> "$temp_dir/manifest.txt"
  echo "" >> "$temp_dir/manifest.txt"
  echo "Contents:" >> "$temp_dir/manifest.txt"
  ls -la "$temp_dir" | grep -v "manifest.txt" >> "$temp_dir/manifest.txt"
  
  # Create the full backup archive
  tar -czf "$full_backup_file" -C "$BACKUP_DIR" "full_backup_temp_$TIMESTAMP"
  
  if [ $? -eq 0 ]; then
    # Remove the temporary directory
    rm -rf "$temp_dir"
    log_success "✅ Full backup archive created: $(basename "$full_backup_file")"
    return 0
  else
    log_error "Failed to create full backup archive"
    rm -rf "$temp_dir"
    return 1
  fi
}

# Function to verify backup integrity
verify_backups() {
  log_message "🔍 Verifying backup integrity..."
  
  local backup_ok=true
  
  # Verify database backup
  local db_backup=$(find "$BACKUP_DIR" -name "x-ui.db.$TIMESTAMP.bak.gz" -type f)
  if [ -n "$db_backup" ]; then
    if gzip -t "$db_backup"; then
      log_success "✅ Database backup verified: $(basename "$db_backup")"
    else
      log_error "❌ Database backup verification failed: $(basename "$db_backup")"
      backup_ok=false
    fi
  else
    log_warning "⚠️ No database backup found for verification"
    backup_ok=false
  fi
  
  # Verify certificate backup
  local cert_backup=$(find "$BACKUP_DIR" -name "certificates_$TIMESTAMP.tar.gz" -type f)
  if [ -n "$cert_backup" ]; then
    if tar -tzf "$cert_backup" > /dev/null 2>&1; then
      log_success "✅ Certificate backup verified: $(basename "$cert_backup")"
    else
      log_error "❌ Certificate backup verification failed: $(basename "$cert_backup")"
      backup_ok=false
    fi
  else
    log_warning "⚠️ No certificate backup found for verification"
    backup_ok=false
  fi
  
  # Verify config backup
  local config_backup=$(find "$BACKUP_DIR" -name "config_$TIMESTAMP.tar.gz" -type f)
  if [ -n "$config_backup" ]; then
    if tar -tzf "$config_backup" > /dev/null 2>&1; then
      log_success "✅ Configuration backup verified: $(basename "$config_backup")"
    else
      log_error "❌ Configuration backup verification failed: $(basename "$config_backup")"
      backup_ok=false
    fi
  else
    log_warning "⚠️ No configuration backup found for verification"
    backup_ok=false
  fi
  
  # Verify full backup
  local full_backup=$(find "$BACKUP_DIR" -name "full_backup_$TIMESTAMP.tar.gz" -type f)
  if [ -n "$full_backup" ]; then
    if tar -tzf "$full_backup" > /dev/null 2>&1; then
      log_success "✅ Full backup archive verified: $(basename "$full_backup")"
    else
      log_error "❌ Full backup archive verification failed: $(basename "$full_backup")"
      backup_ok=false
    fi
  else
    log_warning "⚠️ No full backup archive found for verification"
    backup_ok=false
  fi
  
  if [ "$backup_ok" = true ]; then
    log_success "✅ All backups verified successfully"
    return 0
  else
    log_warning "⚠️ Some backups failed verification"
    return 1
  fi
}

# Main execution
main() {
  log_message "🗃️ Starting comprehensive backup process"
  
  # Set secure permissions on backup directory
  chmod 700 "$BACKUP_DIR"
  
  # Perform backups
  backup_database
  backup_certificates
  backup_config
  
  # Create full backup archive
  create_full_backup
  
  # Verify the backups
  verify_backups
  
  # Clean up old backups
  cleanup_old_backups
  
  # Show backup summary
  log_message "📊 Backup Summary:"
  log_message "  📅 Date: $(date)"
  log_message "  📁 Location: $BACKUP_DIR"
  log_message "  🗄️ DB Backup: x-ui.db.$TIMESTAMP.bak.gz"
  log_message "  🔐 Cert Backup: certificates_$TIMESTAMP.tar.gz"
  log_message "  ⚙️ Config Backup: config_$TIMESTAMP.tar.gz"
  log_message "  📦 Full Archive: full_backup_$TIMESTAMP.tar.gz"
  log_message "  🧹 Retention: $BACKUP_RETENTION_DAYS days"
}

# Execute main function
main

log_message "✅ Backup process completed"
exit 0 