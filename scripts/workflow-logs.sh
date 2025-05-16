#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOGS_DIR="workflow_logs"
LATEST_RUN_DIR="${LOGS_DIR}/run-latest"

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
  echo -e ""
}

# Function to show the latest logs
function show_latest_logs {
  echo -e "${YELLOW}Showing latest workflow logs:${NC}"
  
  if [ ! -d "${LATEST_RUN_DIR}" ]; then
    echo -e "${RED}No workflow logs found. Run with --fetch option to download logs from server.${NC}"
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

# Function to fetch logs from server
function fetch_logs {
  echo -e "${YELLOW}Fetching logs from server...${NC}"
  
  # Check if required environment variables are set
  if [ -z "${SERVER_HOST}" ] || [ -z "${SERVER_USER}" ] || [ -z "${DEPLOY_PATH}" ]; then
    echo -e "${RED}Error: Required environment variables not set.${NC}"
    echo "Please set the following environment variables:"
    echo "  SERVER_HOST: The hostname or IP of the server"
    echo "  SERVER_USER: The SSH username for the server"
    echo "  DEPLOY_PATH: The path where 3x-ui is deployed"
    echo ""
    echo "For example:"
    echo "  export SERVER_HOST=your-server.example.com"
    echo "  export SERVER_USER=username"
    echo "  export DEPLOY_PATH=/path/to/3x-ui"
    return 1
  fi
  
  # Create a timestamp for the run
  RUN_ID=$(date +"%s")
  RUN_DIR="${LOGS_DIR}/run-${RUN_ID}"
  mkdir -p ${RUN_DIR}/select_workflow
  
  # SSH to server and fetch the logs
  echo "Connecting to ${SERVER_USER}@${SERVER_HOST}..."
  scp ${SERVER_USER}@${SERVER_HOST}:${DEPLOY_PATH}/workflow_logs/latest_*.log ${RUN_DIR}/select_workflow/ > /dev/null 2>&1
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to fetch logs from server.${NC}"
    echo "Please check your SSH connection and server path."
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
      *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
    esac
    shift
  done
fi 