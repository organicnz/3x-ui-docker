#!/bin/bash

# Script to generate a comprehensive status report for 3x-ui VPN service
# Usage: ./status-report.sh [--full] [--output=<file>]

set -e

# Default values
FULL_REPORT=false
OUTPUT_FILE=""
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Parse arguments
for arg in "$@"; do
  case $arg in
    --full)
      FULL_REPORT=true
      shift
      ;;
    --output=*)
      OUTPUT_FILE="${arg#*=}"
      shift
      ;;
    --help)
      echo "Usage: ./status-report.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --full                Generate a full detailed report"
      echo "  --output=FILE         Save report to specified file"
      echo "  --help                Show this help message"
      exit 0
      ;;
  esac
done

# If no output file specified, create a default one
if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="logs/status-report_${TIMESTAMP}.log"
fi

# Create directory for output file if it doesn't exist
mkdir -p $(dirname "$OUTPUT_FILE")

# Function to run a command and capture its output
run_command() {
  local cmd="$1"
  local title="$2"
  
  echo "======================================================================"
  echo "# $title"
  echo "======================================================================"
  echo "Running: $cmd"
  echo ""
  
  # Run the command and capture output
  eval "$cmd" | tee -a "$OUTPUT_FILE.tmp"
  
  echo ""
  echo ""
}

# Start capturing output to the temporary file
exec > >(tee -a "$OUTPUT_FILE.tmp") 2>&1

echo "======================================================================"
echo "# 3X-UI VPN SERVICE STATUS REPORT"
echo "# Generated on: $(date)"
echo "======================================================================"
echo ""

# System information
echo "======================================================================"
echo "# SYSTEM INFORMATION"
echo "======================================================================"

echo "Hostname: $(hostname)"
echo "OS: $(uname -s) $(uname -r) $(uname -m)"
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "⚠️  WARNING: Docker is not running or you don't have permissions!"
else
  echo "✅ Docker is running"
fi

echo ""

# Local container status
if docker ps -a --format '{{.Names}}' | grep -q "^3x-ui$"; then
  run_command "./scripts/check-container-status.sh --stats" "LOCAL CONTAINER STATUS"
  
  if [ "$FULL_REPORT" = true ]; then
    run_command "./scripts/check-container-status.sh --logs --lines=100" "LOCAL CONTAINER LOGS"
  else
    run_command "./scripts/check-container-status.sh --logs --lines=20" "LOCAL CONTAINER LOGS (LAST 20 LINES)"
  fi
else
  echo "⚠️  WARNING: Local 3x-ui container not found. Skipping local checks."
  echo ""
fi

# Check for .env file
if [ -f ".env" ]; then
  echo "======================================================================"
  echo "# REMOTE SERVER CHECK"
  echo "======================================================================"
  
  # Load environment variables
  source .env
  
  if [ -n "$SERVER_HOST" ] && [ -n "$SERVER_USER" ]; then
    echo "Checking remote server: ${SERVER_USER}@${SERVER_HOST}"
    echo ""
    
    # Verify SSH connectivity
    if ssh -o BatchMode=yes -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_HOST} "echo 'SSH connection successful'" > /dev/null 2>&1; then
      echo "✅ SSH connection to ${SERVER_HOST} successful"
      
      # Remote server checks
      if [ "$FULL_REPORT" = true ]; then
        run_command "./scripts/check-remote-errors.sh --full --lines=100" "REMOTE SERVER LOGS"
      else
        run_command "./scripts/check-remote-errors.sh --lines=20" "REMOTE SERVER ERRORS"
      fi
    else
      echo "❌ Failed to connect to remote server. Check SSH credentials."
      echo ""
    fi
  else
    echo "⚠️  WARNING: SERVER_HOST or SERVER_USER not set in .env file. Skipping remote checks."
    echo ""
  fi
else
  echo "⚠️  WARNING: .env file not found. Skipping remote server checks."
  echo ""
fi

# GitHub workflow checks
if [ -f ".env" ] && [ -n "$GITHUB_TOKEN" ]; then
  echo "======================================================================"
  echo "# GITHUB WORKFLOW CHECK"
  echo "======================================================================"
  
  run_command "./scripts/check-workflow-logs.sh --latest" "GITHUB WORKFLOW STATUS"
else
  echo "⚠️  WARNING: GITHUB_TOKEN not set in .env file. Skipping workflow checks."
  echo ""
fi

# Final summary
echo "======================================================================"
echo "# SUMMARY"
echo "======================================================================"

echo "Status report completed at: $(date)"
echo "Full report saved to: $OUTPUT_FILE"
echo ""

# Move the temporary file to the final output file
mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

echo "✅ Status report completed!"
echo "📋 The report has been saved to: $OUTPUT_FILE" 