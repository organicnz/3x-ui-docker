#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Change to the directory where the script is located
cd "$(dirname "$0")/.." || exit 1

# Source the utility library
if [ -f "scripts/utils.sh" ]; then
  source scripts/utils.sh
else
  echo "Error: utils.sh not found. Make sure you're running the script from the project root."
  exit 1
fi

# Load environment variables from .env file
if [ -f ".env" ]; then
  source .env
else
  echo -e "${YELLOW}No .env file found. Some functions may be limited.${NC}"
fi

# Function to display the main menu
function show_menu {
  clear
  echo -e "${BLUE}==============================================${NC}"
  echo -e "${CYAN}       3x-ui VPN Administration Tool         ${NC}"
  echo -e "${BLUE}==============================================${NC}"
  echo -e ""
  echo -e "${GREEN}1.${NC} Environment Setup"
  echo -e "${GREEN}2.${NC} View Workflow Status (GitHub)"
  echo -e "${GREEN}3.${NC} Fetch Remote Logs"
  echo -e "${GREEN}4.${NC} View Latest Logs"
  echo -e "${GREEN}5.${NC} View All Available Logs"
  echo -e "${GREEN}6.${NC} Deploy VPN Service"
  echo -e "${GREEN}7.${NC} SSH to VPN Server"
  echo -e "${GREEN}8.${NC} Check Server Status"
  echo -e "${GREEN}0.${NC} Exit"
  echo -e ""
  echo -e "${BLUE}==============================================${NC}"
  echo -e "Current environment: ${YELLOW}${SERVER_USER}@${SERVER_HOST}${NC}"
  echo -e "${BLUE}==============================================${NC}"
  echo -e ""
}

# Function to handle environment setup
function setup_environment {
  ./scripts/setup-env.sh
  echo -e ""
  read -p "Press Enter to continue..."
}

# Function to check GitHub workflow status
function check_workflow_status {
  ./scripts/check-workflow-status.sh
  echo -e ""
  read -p "Press Enter to continue..."
}

# Function to fetch remote logs
function fetch_remote_logs {
  ./scripts/workflow-logs.sh -f
  echo -e ""
  read -p "Press Enter to continue..."
}

# Function to view latest logs
function view_latest_logs {
  ./scripts/workflow-logs.sh -l
  echo -e ""
  read -p "Press Enter to continue..."
}

# Function to view all logs
function view_all_logs {
  ./scripts/workflow-logs.sh -a
  echo -e ""
  read -p "Press Enter to continue..."
}

# Function to deploy VPN service
function deploy_vpn {
  echo -e "${BLUE}VPN Deployment Options:${NC}"
  echo -e ""
  echo -e "${GREEN}1.${NC} Deploy via GitHub Actions"
  echo -e "${GREEN}2.${NC} Manual Deployment"
  echo -e "${GREEN}0.${NC} Back to Main Menu"
  echo -e ""
  read -p "Select an option: " deploy_choice
  
  case $deploy_choice in
    1)
      echo -e "${YELLOW}Triggering GitHub Actions deployment...${NC}"
      echo -e "${BLUE}Visit: https://github.com/${REPO_OWNER}/${REPO_NAME}/actions/workflows/3x-ui-workflow.yml${NC}"
      echo -e "Click 'Run workflow' button and select the appropriate options."
      echo -e ""
      read -p "Press Enter to continue..."
      ;;
    2)
      echo -e "${YELLOW}Performing manual deployment...${NC}"
      # If we have SSH credentials, perform deployment
      if [ -n "$SERVER_HOST" ] && [ -n "$SERVER_USER" ]; then
        echo -e "Connecting to ${SERVER_USER}@${SERVER_HOST}..."
        
        # Check if the deploy directory exists, create if not
        SSH_OPTIONS=$(get_ssh_options)
        
        # Test SSH connection first
        test_ssh_connection "$SSH_OPTIONS"
        if [ $? -ne 0 ]; then
          echo -e ""
          read -p "Press Enter to continue..."
          return
        fi
        
        # Check & create deploy path if needed
        ensure_deploy_path "$SSH_OPTIONS"
        if [ $? -ne 0 ]; then
          echo -e ""
          read -p "Press Enter to continue..."
          return
        fi
        
        # SSH to server and perform deployment
        echo -e "${BLUE}Running deployment commands...${NC}"
        eval "autossh -M 0 $SSH_OPTIONS $SERVER_USER@$SERVER_HOST \"cd $DEPLOY_PATH && docker-compose pull && docker-compose up -d\""
        
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}Deployment completed successfully.${NC}"
        else
          echo -e "${RED}Deployment failed. Check SSH connection and server status.${NC}"
        fi
      else
        echo -e "${RED}Error: SERVER_HOST and SERVER_USER must be set in .env file.${NC}"
      fi
      echo -e ""
      read -p "Press Enter to continue..."
      ;;
    0|"")
      return
      ;;
    *)
      echo -e "${RED}Invalid option.${NC}"
      read -p "Press Enter to continue..."
      ;;
  esac
}

# Function to SSH to VPN server
function ssh_to_server {
  if [ -z "$SERVER_HOST" ] || [ -z "$SERVER_USER" ]; then
    echo -e "${RED}Error: SERVER_HOST and SERVER_USER must be set in .env file.${NC}"
    echo -e "Run option 1 to set up your environment first."
    echo -e ""
    read -p "Press Enter to continue..."
    return
  fi
  
  echo -e "${BLUE}Connecting to ${SERVER_USER}@${SERVER_HOST}...${NC}"
  
  # Get SSH options
  SSH_OPTIONS=$(get_ssh_options)
  
  # SSH to server
  eval "autossh -M 0 $SSH_OPTIONS $SERVER_USER@$SERVER_HOST"
  
  # Return to the menu when SSH session ends
  clear
}

# Function to check server status
function check_server_status {
  if [ -z "$SERVER_HOST" ] || [ -z "$SERVER_USER" ]; then
    echo -e "${RED}Error: SERVER_HOST and SERVER_USER must be set in .env file.${NC}"
    echo -e "Run option 1 to set up your environment first."
    echo -e ""
    read -p "Press Enter to continue..."
    return
  fi
  
  echo -e "${BLUE}Checking server status for ${SERVER_USER}@${SERVER_HOST}...${NC}"
  
  # Get SSH options
  SSH_OPTIONS=$(get_ssh_options)
  
  # Test SSH connection
  test_ssh_connection "$SSH_OPTIONS"
  if [ $? -ne 0 ]; then
    echo -e ""
    read -p "Press Enter to continue..."
    return
  fi
  
  # SSH to server and check status
  echo -e "${YELLOW}Docker container status:${NC}"
  eval "autossh -M 0 $SSH_OPTIONS $SERVER_USER@$SERVER_HOST \"docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'\""
  
  echo -e "\n${YELLOW}System resources:${NC}"
  eval "autossh -M 0 $SSH_OPTIONS $SERVER_USER@$SERVER_HOST \"echo 'CPU: ' && top -bn1 | grep 'Cpu(s)' && echo 'Memory: ' && free -h\""
  
  echo -e "\n${YELLOW}Disk usage:${NC}"
  eval "autossh -M 0 $SSH_OPTIONS $SERVER_USER@$SERVER_HOST \"df -h /\""
  
  echo -e ""
  read -p "Press Enter to continue..."
}

# Load environment variables first
load_env_variables

# Main loop
while true; do
  show_menu
  read -p "Select an option: " choice
  
  case $choice in
    1)
      setup_environment
      ;;
    2)
      check_workflow_status
      ;;
    3)
      fetch_remote_logs
      ;;
    4)
      view_latest_logs
      ;;
    5)
      view_all_logs
      ;;
    6)
      deploy_vpn
      ;;
    7)
      ssh_to_server
      ;;
    8)
      check_server_status
      ;;
    0|exit|quit|q)
      echo -e "${GREEN}Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option.${NC}"
      read -p "Press Enter to continue..."
      ;;
  esac
done 