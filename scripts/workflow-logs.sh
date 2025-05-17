#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")/.." || exit 1

# Source the utility library
if [ -f "scripts/utils.sh" ]; then
  source scripts/utils.sh
else
  echo "Error: utils.sh not found. Make sure you're running the script from the project root."
  exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOGS_DIR="workflow_logs"
LATEST_RUN_DIR="${LOGS_DIR}/run-latest"

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
  SERVER_HOST=${SERVER_HOST:-$VPN_DOMAIN}
  SERVER_USER=${SERVER_USER:-root}
  DEPLOY_PATH=${DEPLOY_PATH:-/home/organic/dev/3x-ui}
  echo -e "${BLUE}Environment loaded:${NC}"
  echo -e "  SERVER_HOST: ${SERVER_HOST:-not set}"
  echo -e "  SERVER_USER: ${SERVER_USER:-not set}"
  echo -e "  DEPLOY_PATH: ${DEPLOY_PATH:-not set}"
  echo -e ""
}

# Make sure the logs directory exists
mkdir -p ${LOGS_DIR}

# Function to display usage instructions
function show_help {
  echo -e "${BLUE}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${BLUE}Options:${NC}"
  echo -e "  -h, --help     Show this help message"
  echo -e "  -l, --latest   Show latest logs (default)"
  echo -e "  -f, --fetch    Fetch logs from server (requires SSH access)"
  echo -e "  -a, --all      Show all available logs"
  echo -e "  -g, --github   Instructions for checking GitHub Actions logs"
  echo -e "  -e, --env      Show loaded environment variables"
  echo -e "  -c, --check    Check remote server setup"
  echo -e ""
}

# Function to show the latest logs
function show_latest_logs {
  echo -e "${YELLOW}Showing latest workflow logs:${NC}"
  
  if [ ! -d "${LATEST_RUN_DIR}" ]; then
    echo -e "${RED}No workflow logs found. Run with --fetch option to download logs from server.${NC}"
    echo -e "${YELLOW}Or run with --github to get instructions for checking GitHub Actions logs.${NC}"
    return 1
  fi
  
  if [ -f "${LATEST_RUN_DIR}/select_workflow/latest_deploy.log" ]; then
    echo -e "${GREEN}=== Latest Deployment Log ===${NC}"
    cat "${LATEST_RUN_DIR}/select_workflow/latest_deploy.log"
    echo ""
  fi
  
  if [ -f "${LATEST_RUN_DIR}/select_workflow/latest_verify.log" ]; then
    echo -e "${GREEN}=== Latest Verification Log ===${NC}"
    cat "${LATEST_RUN_DIR}/select_workflow/latest_verify.log"
    echo ""
  fi
}

# Function to show GitHub Actions instructions
function show_github_instructions {
  echo -e "${BLUE}=== CHECKING GITHUB ACTIONS WORKFLOW LOGS ===${NC}"
  echo -e ""
  echo -e "Since GitHub Actions secrets can't be accessed locally, follow these steps to view workflow logs:"
  echo -e ""
  echo -e "${YELLOW}1. Visit GitHub Actions page:${NC}"
  echo -e "   https://github.com/${REPO_OWNER}/${REPO_NAME}/actions"
  echo -e ""
  echo -e "${YELLOW}2. Click on the latest workflow run (named \"3x-ui VPN Deployment\")${NC}"
  echo -e ""
  echo -e "${YELLOW}3. Review logs for each workflow step${NC}"
  echo -e ""
  echo -e "${BLUE}=== USING LOCAL ENVIRONMENT VARIABLES FOR LOG FETCHING ===${NC}"
  echo -e ""
  echo -e "Your environment is currently configured as:"
  echo -e "  SERVER_HOST: ${SERVER_HOST}"
  echo -e "  SERVER_USER: ${SERVER_USER}"
  echo -e "  DEPLOY_PATH: ${DEPLOY_PATH}"
  echo -e ""
  
  if [ -z "${SERVER_HOST}" ] || [ -z "${SERVER_USER}" ] || [ -z "${DEPLOY_PATH}" ]; then
    echo -e "${YELLOW}Some required variables are not set.${NC}"
    echo -e "Make sure these values are defined in your .env file or set them manually:"
    echo -e "  SERVER_HOST - The hostname or IP address of your server"
    echo -e "  SERVER_USER - The SSH username for the server"
    echo -e "  DEPLOY_PATH - The deployment path on the server"
    echo -e ""
    echo -e "You can find these values in your GitHub repository secrets at:"
    echo -e "  https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/secrets/actions"
    echo -e ""
    echo -e "Or set them manually with:"
    echo -e "  export SERVER_HOST=your-server-hostname"
    echo -e "  export SERVER_USER=your-server-username"
    echo -e "  export DEPLOY_PATH=your-deployment-path"
    echo -e ""
  fi
  
  echo -e "After ensuring these variables are set, you can run: $0 -f"
  echo -e ""
}

# Function to check remote server setup
function check_remote_setup {
  if [ -z "${SERVER_HOST}" ] || [ -z "${SERVER_USER}" ]; then
    echo -e "${RED}Error: SERVER_HOST and SERVER_USER must be set.${NC}"
    return 1
  fi
  
  echo -e "${BLUE}Checking remote server setup...${NC}"
  
  # Get SSH options
  SSH_OPTIONS=$(get_ssh_options)
  
  # Test SSH connection
  test_ssh_connection "$SSH_OPTIONS"
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Check & create deploy path if needed
  ensure_deploy_path "$SSH_OPTIONS"
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Check & create logs directory if needed
  ensure_logs_directory "$SSH_OPTIONS"
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Check & create log files if needed
  ensure_log_files "$SSH_OPTIONS"
  
  echo -e "${GREEN}Remote server setup check completed successfully.${NC}"
  return 0
}

# Function to fetch logs from server
function fetch_logs {
  echo -e "${YELLOW}Fetching logs from server...${NC}"
  
  # Check if required environment variables are set
  if [ -z "${SERVER_HOST}" ] || [ -z "${SERVER_USER}" ] || [ -z "${DEPLOY_PATH}" ]; then
    echo -e "${RED}Error: Required environment variables not set.${NC}"
    echo -e "${YELLOW}These variables should be in your .env file or set manually.${NC}"
    echo -e ""
    echo "Please ensure the following environment variables are set:"
    echo "  SERVER_HOST: The hostname or IP of the server"
    echo "  SERVER_USER: The SSH username for the server"
    echo "  DEPLOY_PATH: The path where 3x-ui is deployed"
    echo ""
    echo "For example in your .env file:"
    echo "  SERVER_HOST=your-server.example.com"
    echo "  SERVER_USER=username"
    echo "  DEPLOY_PATH=/path/to/3x-ui"
    echo ""
    echo -e "${YELLOW}Run with --github for instructions on viewing logs in GitHub Actions.${NC}"
    return 1
  fi
  
  # First check if the remote setup is correct
  check_remote_setup
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Remote server setup check failed.${NC}"
    echo -e "Please fix the issues above before fetching logs."
    return 1
  fi
  
  # Create a timestamp for the run
  RUN_ID=$(date +"%s")
  RUN_DIR="${LOGS_DIR}/run-${RUN_ID}"
  mkdir -p ${RUN_DIR}/select_workflow
  
  # SSH to server and fetch the logs
  echo -e "${BLUE}Connecting to ${SERVER_USER}@${SERVER_HOST} to fetch logs...${NC}"
  
  # Get SSH options
  SSH_OPTIONS=$(get_ssh_options)
  
  # Now fetch the logs
  eval "scp $SSH_OPTIONS ${SERVER_USER}@${SERVER_HOST}:${DEPLOY_PATH}/workflow_logs/latest_*.log ${RUN_DIR}/select_workflow/" 2>/dev/null
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to fetch logs from server.${NC}"
    echo "Please check your SSH connection and server path."
    echo "Make sure your SSH key is properly configured and you have access to the server."
    echo ""
    echo -e "${YELLOW}If you're using GitHub Actions SSH key:${NC}"
    echo "1. The GitHub Actions workflow uses a dedicated SSH key stored in secrets"
    echo "2. Your local SSH key may be different"
    echo "3. Consider setting up your SSH configuration (~/.ssh/config) with the correct key"
    echo "4. Or specify the SSH key path in your .env file with SSH_KEY_PATH variable"
    echo ""
    echo -e "${YELLOW}Run with --check to diagnose server setup issues.${NC}"
    rm -rf ${RUN_DIR}
    return 1
  fi
  
  # Update the symlink to the latest run
  rm -rf ${LATEST_RUN_DIR}
  ln -sf "run-${RUN_ID}" ${LATEST_RUN_DIR}
  
  echo -e "${GREEN}Logs fetched successfully.${NC}"
  return 0
}

# Function to show all available logs
function show_all_logs {
  echo -e "${YELLOW}Available workflow runs:${NC}"
  
  # Check if logs directory exists
  if [ ! -d "${LOGS_DIR}" ] || [ -z "$(ls -A ${LOGS_DIR})" ]; then
    echo -e "${RED}No workflow logs found. Run with --fetch option to download logs from server.${NC}"
    echo -e "${YELLOW}Or run with --github to get instructions for checking GitHub Actions logs.${NC}"
    return 1
  fi
  
  # List all runs (using globs instead of ls)
  runs=( ${LOGS_DIR}/run-* )
  runs=( $(printf '%s\n' "${runs[@]}" | sort -r) )
  
  for run in "${runs[@]}"; do
    if [ ! -d "${run}" ]; then
      continue
    fi
    
    run_id=$(basename "${run}")
    timestamp=${run_id#run-}
    if [[ ${timestamp} =~ ^[0-9]+$ ]]; then
      date_str=$(date -r ${timestamp} "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
      if [ $? -ne 0 ]; then
        date_str="Unknown"
      fi
    else
      date_str="Unknown"
    fi
    
    echo -e "${BLUE}${run_id}${NC} (${date_str})"
    
    # List log files in the run (using globs instead of ls)
    if [ -d "${run}/select_workflow" ]; then
      log_files=( "${run}/select_workflow"/*.log )
      if [ -e "${log_files[0]}" ]; then
        for log in "${log_files[@]}"; do
          log_file=$(basename "${log}")
          echo "  - ${log_file}"
        done
      else
        echo "  No log files found"
      fi
    else
      echo "  No logs available"
    fi
    echo ""
  done
  
  return 0
}

# Function to show environment variables
function show_env_variables {
  echo -e "${BLUE}Current Environment Variables:${NC}"
  echo -e "${YELLOW}SERVER_HOST:${NC} ${SERVER_HOST}"
  echo -e "${YELLOW}SERVER_USER:${NC} ${SERVER_USER}"
  echo -e "${YELLOW}DEPLOY_PATH:${NC} ${DEPLOY_PATH}"
  echo -e "${YELLOW}SSH_KEY_PATH:${NC} ${SSH_KEY_PATH:-not set}"
  echo -e ""
  
  if [ -z "${SERVER_HOST}" ] || [ -z "${SERVER_USER}" ] || [ -z "${DEPLOY_PATH}" ]; then
    echo -e "${RED}Warning: Some required variables are not set.${NC}"
    echo -e "These should be defined in your .env file for proper operation."
    echo -e ""
  else
    echo -e "${GREEN}All required variables are set.${NC}"
    echo -e ""
  fi
}

# Load environment variables first
load_env_variables

# Parse command line arguments
if [ $# -eq 0 ]; then
  # Default action: show latest logs
  show_latest_logs
else
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -l|--latest)
        show_latest_logs
        ;;
      -f|--fetch)
        fetch_logs
        if [ $? -eq 0 ]; then
          show_latest_logs
        fi
        ;;
      -a|--all)
        show_all_logs
        ;;
      -g|--github)
        show_github_instructions
        ;;
      -e|--env)
        show_env_variables
        ;;
      -c|--check)
        check_remote_setup
        ;;
      *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
    esac
    shift
  done
fi 