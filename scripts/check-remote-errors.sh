#!/bin/bash

# Script to check 3x-ui-vpn errors remotely via CLI
# Usage: ./check-remote-errors.sh [--full] [--lines=100]

set -e

# Default values
LINES=50
FULL_LOGS=false
ERROR_ONLY=true

# Load environment variables
if [ -f ".env" ]; then
  source .env
else
  echo "Error: .env file not found. Please create it with SERVER_HOST, SERVER_USER and other required variables."
  exit 1
fi

# Parse arguments
for arg in "$@"; do
  case $arg in
    --full)
      FULL_LOGS=true
      ERROR_ONLY=false
      shift
      ;;
    --lines=*)
      LINES="${arg#*=}"
      shift
      ;;
    --all)
      ERROR_ONLY=false
      shift
      ;;
    --help)
      echo "Usage: ./check-remote-errors.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --full         Show full logs without filtering"
      echo "  --lines=N      Show last N lines (default: 50)"
      echo "  --all          Show all log entries, not just errors"
      echo "  --help         Show this help message"
      exit 0
      ;;
  esac
done

echo "🔍 Connecting to ${SERVER_USER}@${SERVER_HOST}..."

# Function to check if container is running
check_container() {
  echo "🧪 Checking if 3x-ui container is running..."
  CONTAINER_STATUS=$(ssh ${SERVER_USER}@${SERVER_HOST} "docker ps --filter name=3x-ui --format '{{.Status}}'")
  
  if [ -z "$CONTAINER_STATUS" ]; then
    echo "❌ Error: 3x-ui container is not running!"
    echo "ℹ️  Try to start it using: ssh ${SERVER_USER}@${SERVER_HOST} 'cd ${DEPLOY_PATH} && docker-compose up -d'"
    exit 1
  else
    echo "✅ 3x-ui container is running: $CONTAINER_STATUS"
  fi
}

# Function to fetch logs
fetch_logs() {
  echo "📥 Fetching logs from 3x-ui container..."
  
  if [ "$FULL_LOGS" = true ]; then
    # Get all logs
    ssh ${SERVER_USER}@${SERVER_HOST} "docker logs --tail=${LINES} 3x-ui" > temp_logs.txt
  else
    # Get filtered logs
    ssh ${SERVER_USER}@${SERVER_HOST} "docker logs --tail=1000 3x-ui" > temp_logs.txt
  fi
  
  # Count total lines
  TOTAL_LINES=$(wc -l < temp_logs.txt)
  echo "📋 Retrieved $TOTAL_LINES log entries"
}

# Function to filter and display errors
display_errors() {
  echo "🔎 Analyzing logs for errors..."
  
  if [ "$ERROR_ONLY" = true ]; then
    # Filter for error messages
    ERROR_COUNT=$(grep -i -E "error|exception|fail|fatal|critical|warn|panic" temp_logs.txt | wc -l)
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
      echo "✅ No errors found in the last ${LINES} log entries!"
    else
      echo "⚠️  Found $ERROR_COUNT error entries:"
      echo "---------------------------------------------------------------------------------"
      grep -i -E "error|exception|fail|fatal|critical|warn|panic" temp_logs.txt | tail -n ${LINES}
      echo "---------------------------------------------------------------------------------"
    fi
  else
    # Display all logs (based on lines parameter)
    echo "📜 Last ${LINES} log entries:"
    echo "---------------------------------------------------------------------------------"
    tail -n ${LINES} temp_logs.txt
    echo "---------------------------------------------------------------------------------"
  fi
  
  # Clean up
  rm temp_logs.txt
}

# Function to check system status
check_system_status() {
  echo "🖥️  Checking system resource usage..."
  
  # Get container stats
  ssh ${SERVER_USER}@${SERVER_HOST} "docker stats 3x-ui --no-stream --format 'CPU: {{.CPUPerc}}, Memory: {{.MemUsage}}, Network I/O: {{.NetIO}}'"
  
  # Check disk space
  echo "💾 Disk space usage:"
  ssh ${SERVER_USER}@${SERVER_HOST} "df -h | grep -E '/$|/home'"
}

# Main execution
check_container
fetch_logs
display_errors
check_system_status

echo "✅ Remote error check completed!" 