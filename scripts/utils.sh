#!/bin/bash

# Utility functions for 3x-ui VPN admin scripts

# Colors for output
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Default values
DEFAULT_SERVER_HOST="64.227.113.96"
DEFAULT_SERVER_USER="organic"
DEFAULT_DEPLOY_PATH="/home/organic/dev/3x-ui"
DEFAULT_REPO_OWNER="organicnz"
DEFAULT_REPO_NAME="3x-ui-docker"

# Load environment variables from .env file
function load_env_variables {
  echo -e "${BLUE}Loading environment variables...${NC}"
  # Check for .env file
  if [ -f ".env" ]; then
    echo -e "${GREEN}Loading from .env file${NC}"
    set -a
    source .env
    set +a
  elif [ -f "env.example" ]; then
    echo -e "${YELLOW}No .env file found, but env.example exists.${NC}"
    echo -e "${YELLOW}Consider creating a .env file based on env.example:${NC}"
    echo -e "  cp env.example .env"
    echo -e "  # Then edit .env with your actual values"
  else
    echo -e "${RED}No .env or env.example file found.${NC}"
  fi
  
  # Check if required variables are set or use defaults
  export SERVER_HOST=${SERVER_HOST:-$DEFAULT_SERVER_HOST}
  export SERVER_USER=${SERVER_USER:-$DEFAULT_SERVER_USER}
  export DEPLOY_PATH=${DEPLOY_PATH:-$DEFAULT_DEPLOY_PATH}
  export REPO_OWNER=${REPO_OWNER:-$DEFAULT_REPO_OWNER}
  export REPO_NAME=${REPO_NAME:-$DEFAULT_REPO_NAME}
  
  echo -e "${BLUE}Environment loaded:${NC}"
  echo -e "  SERVER_HOST: ${SERVER_HOST}"
  echo -e "  SERVER_USER: ${SERVER_USER}"
  echo -e "  DEPLOY_PATH: ${DEPLOY_PATH}"
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