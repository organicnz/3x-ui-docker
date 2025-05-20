#!/bin/bash

# Utility functions for 3x-ui VPN Service scripts
# This file contains common functions used across various scripts

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log a regular message
log_message() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${BLUE}[${timestamp}]${NC} $1"
}

# Log a success message
log_success() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${GREEN}[${timestamp}]${NC} $1"
}

# Log a warning message
log_warning() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${YELLOW}[${timestamp}]${NC} $1"
}

# Log an error message
log_error() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${RED}[${timestamp}]${NC} $1"
}

# Check if running as root
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_warning "This script is not running as root."
    log_warning "Some operations may fail due to insufficient permissions."
    return 1
  fi
  return 0
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if a file exists
file_exists() {
  [ -f "$1" ]
}

# Check if a directory exists
dir_exists() {
  [ -d "$1" ]
}

# Check if a service is running
service_running() {
  if command_exists systemctl; then
    systemctl is-active --quiet "$1"
    return $?
  elif command_exists service; then
    service "$1" status >/dev/null 2>&1
    return $?
  else
    log_error "Cannot check service status: neither systemctl nor service command found"
    return 2
  fi
}

# Execute a command and log output
exec_cmd() {
  local cmd="$1"
  local cmd_name="${2:-Command}"
  
  log_message "Executing: $cmd"
  
  # Execute the command and capture output
  output=$(eval "$cmd" 2>&1)
  exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    log_success "$cmd_name completed successfully"
    [ -n "$output" ] && echo "$output"
    return 0
  else
    log_error "$cmd_name failed with exit code $exit_code"
    [ -n "$output" ] && echo "$output"
    return $exit_code
  fi
}

# Create a backup of a file before modifying it
backup_file() {
  local file="$1"
  local backup="${file}.bak_$(date +%Y%m%d_%H%M%S)"
  
  if [ ! -f "$file" ]; then
    log_error "Cannot backup $file: file does not exist"
    return 1
  fi
  
  cp "$file" "$backup"
  if [ $? -eq 0 ]; then
    log_success "Created backup of $file at $backup"
    return 0
  else
    log_error "Failed to create backup of $file"
    return 1
  fi
}

# Print section header
print_section() {
  local section_name="$1"
  local line=$(printf "%0.s=" $(seq 1 ${#section_name}))
  echo ""
  echo -e "${CYAN}${section_name}${NC}"
  echo -e "${CYAN}${line}${NC}"
}

# Confirmation prompt
confirm() {
  local prompt="${1:-Are you sure?}"
  local default="${2:-Y}"
  
  local options="Y/n"
  if [ "$default" = "N" ] || [ "$default" = "n" ]; then
    options="y/N"
  fi
  
  read -p "$prompt [$options]: " answer
  answer=${answer:-$default}
  
  if [[ $answer =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# Get human-readable file size
get_file_size() {
  local file="$1"
  
  if [ ! -f "$file" ]; then
    echo "0B"
    return 1
  fi
  
  # Get file size in bytes
  local size=$(stat -f "%z" "$file" 2>/dev/null || stat -c "%s" "$file" 2>/dev/null)
  
  # Convert to human-readable format
  if [ $size -lt 1024 ]; then
    echo "${size}B"
  elif [ $size -lt $((1024*1024)) ]; then
    echo "$((size/1024))KB"
  elif [ $size -lt $((1024*1024*1024)) ]; then
    echo "$((size/(1024*1024)))MB"
  else
    echo "$((size/(1024*1024*1024)))GB"
  fi
}

# Wait for a service to be available
wait_for_service() {
  local host="$1"
  local port="$2"
  local timeout="${3:-60}"
  local message="${4:-Waiting for service at $host:$port...}"
  
  log_message "$message"
  
  local start_time=$(date +%s)
  local end_time=$((start_time + timeout))
  
  while [ $(date +%s) -lt $end_time ]; do
    if nc -z "$host" "$port" >/dev/null 2>&1; then
      log_success "Service at $host:$port is available"
      return 0
    fi
    sleep 1
  done
  
  log_error "Service at $host:$port is not available after ${timeout}s timeout"
  return 1
}

# Always require .env for environment variables
# If .env or any required variable is missing, exit with error
function load_env_variables {
  echo -e "${BLUE}Loading environment variables...${NC}"
  if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found. Please create one based on env.example.${NC}"
    exit 1
  fi
  set -a
  source .env
  set +a
  # Check required variables
  missing_vars=()
  for var in SERVER_HOST SERVER_USER DEPLOY_PATH REPO_OWNER REPO_NAME; do
    if [ -z "${!var}" ]; then
      missing_vars+=("$var")
    fi
  done
  if [ ${#missing_vars[@]} -ne 0 ]; then
    echo -e "${RED}Error: The following required variables are missing in .env:${NC} ${missing_vars[*]}"
    exit 1
  fi
  echo -e "${BLUE}Environment loaded:${NC}"
  echo -e "  SERVER_HOST: ${SERVER_HOST}"
  echo -e "  SERVER_USER: ${SERVER_USER}"
  echo -e "  DEPLOY_PATH: ${DEPLOY_PATH}"
  echo -e "  REPO_OWNER: ${REPO_OWNER}"
  echo -e "  REPO_NAME: ${REPO_NAME}"
  echo -e ""
}

# Function to get SSH options
function get_ssh_options {
  local options=""
  
  options='-o "ServerAliveInterval 60000" -o "ServerAliveCountMax 6000"'
  
  # If SSH_KEY_PATH is set, use it, otherwise try default GitLab key location
  if [ ! -z "${SSH_KEY_PATH}" ]; then
    options="$options -i ${SSH_KEY_PATH}"
  elif [ -f ~/.ssh/id_rsa_gitlab ]; then
    options="$options -i ~/.ssh/id_rsa_gitlab"
  fi
  
  echo "$options"
}

# Function to check if remote deploy path exists and create it if needed
function ensure_deploy_path {
  local ssh_options="$1"
  
  echo -e "${YELLOW}Checking if deploy path exists: ${DEPLOY_PATH}${NC}"
  eval "autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"[ -d \\\"${DEPLOY_PATH}\\\" ]\"" 2>/dev/null
  
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Deploy path ${DEPLOY_PATH} does not exist.${NC}"
    echo -e "${GREEN}Automatically creating deployment directory...${NC}"
    eval "autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"mkdir -p ${DEPLOY_PATH}/workflow_logs\"" 2>/dev/null
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Created deploy path and workflow_logs directory.${NC}"
      return 0
    else
      echo -e "${RED}Failed to create directories. Check permissions.${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}Deploy path exists.${NC}"
    return 0
  fi
}

# Function to ensure logs directory exists
function ensure_logs_directory {
  local ssh_options="$1"
  
  echo -e "${YELLOW}Checking if workflow_logs directory exists...${NC}"
  eval "autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"[ -d \\\"${DEPLOY_PATH}/workflow_logs\\\" ]\"" 2>/dev/null
  
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Workflow logs directory does not exist.${NC}"
    echo -e "Creating workflow_logs directory..."
    eval "autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"mkdir -p ${DEPLOY_PATH}/workflow_logs\"" 2>/dev/null
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Created workflow_logs directory.${NC}"
      return 0
    else
      echo -e "${RED}Failed to create workflow_logs directory. Check permissions.${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}Workflow logs directory exists.${NC}"
    return 0
  fi
}

# Test SSH connection
function test_ssh_connection {
  local ssh_options="$1"
  
  echo -e "${YELLOW}Testing SSH connection to ${SERVER_USER}@${SERVER_HOST}...${NC}"
  eval "autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"echo Connected successfully\"" >/dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}SSH connection successful.${NC}"
    return 0
  else
    echo -e "${RED}Error: Cannot connect to the server via SSH.${NC}"
    echo -e "Check your SSH credentials and connection settings."
    echo -e "The following command is being used for SSH connections:"
    echo -e "  autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST"
    echo -e ""
    echo -e "Try running the following command manually to debug:"
    echo -e "  autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"echo Connected successfully\""
    return 1
  fi
}

# Ensure log files exist
function ensure_log_files {
  local ssh_options="$1"
  
  echo -e "${YELLOW}Checking for log files...${NC}"
  local log_count=$(eval "autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"ls -1 ${DEPLOY_PATH}/workflow_logs/latest_*.log 2>/dev/null | wc -l\"")
  
  if [ "$log_count" -gt 0 ]; then
    echo -e "${GREEN}Found ${log_count} log files.${NC}"
    return 0
  else
    echo -e "${YELLOW}No log files found. Creating dummy log files for testing...${NC}"
    eval "autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"echo 'This is a test deploy log' > ${DEPLOY_PATH}/workflow_logs/latest_deploy.log\""
    eval "autossh -M 0 $ssh_options $SERVER_USER@$SERVER_HOST \"echo 'This is a test verify log' > ${DEPLOY_PATH}/workflow_logs/latest_verify.log\""
    echo -e "${GREEN}Created test log files.${NC}"
    return 0
  fi
} 