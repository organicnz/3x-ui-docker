#!/bin/bash

# Utility functions for 3x-ui VPN admin scripts

# Colors for output
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

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