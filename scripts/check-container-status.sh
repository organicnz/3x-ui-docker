#!/bin/bash

# Script to check local Docker container status and logs
# Usage: ./check-container-status.sh [--logs] [--stats] [--all]

set -e

# Default values
CHECK_LOGS=false
CHECK_STATS=false
LINES=50
CONTAINER_NAME="3x-ui"

# Parse arguments
for arg in "$@"; do
  case $arg in
    --logs)
      CHECK_LOGS=true
      shift
      ;;
    --stats)
      CHECK_STATS=true
      shift
      ;;
    --all)
      CHECK_LOGS=true
      CHECK_STATS=true
      shift
      ;;
    --lines=*)
      LINES="${arg#*=}"
      shift
      ;;
    --container=*)
      CONTAINER_NAME="${arg#*=}"
      shift
      ;;
    --help)
      echo "Usage: ./check-container-status.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --logs               Show container logs"
      echo "  --stats              Show container stats"
      echo "  --all                Show both logs and stats (default)"
      echo "  --lines=N            Show last N lines of logs (default: 50)"
      echo "  --container=NAME     Specify container name (default: 3x-ui)"
      echo "  --help               Show this help message"
      exit 0
      ;;
  esac
done

# If no specific check is requested, check all
if [ "$CHECK_LOGS" = false ] && [ "$CHECK_STATS" = false ]; then
  CHECK_LOGS=true
  CHECK_STATS=true
fi

# Function to check if Docker is running
check_docker() {
  if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running or you don't have permissions!"
    exit 1
  fi
}

# Function to check if container exists
check_container_exists() {
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Error: Container '${CONTAINER_NAME}' does not exist!"
    echo ""
    echo "Available containers:"
    docker ps -a --format "{{.Names}}"
    exit 1
  fi
}

# Function to check if container is running
check_container_running() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "⚠️  Warning: Container '${CONTAINER_NAME}' exists but is not running!"
    echo ""
    echo "Container status:"
    docker ps -a --filter "name=${CONTAINER_NAME}" --format "{{.Status}}"
    echo ""
    echo "Start with: docker start ${CONTAINER_NAME}"
    return 1
  fi
  return 0
}

# Function to show container stats
show_container_stats() {
  echo "======================================================================"
  echo "📊 CONTAINER STATS for '${CONTAINER_NAME}'"
  echo "======================================================================"
  
  # Get container info
  echo "🔍 Container Information:"
  docker inspect --format '{{printf "ID: %s\nName: %s\nImage: %s\nCreated: %s\nStatus: %s\nHealth: %s"
    .Id .Name .Config.Image .Created .State.Status .State.Health.Status}}' ${CONTAINER_NAME}
  
  echo ""
  echo "🖥️  Resource Usage:"
  docker stats ${CONTAINER_NAME} --no-stream --format 'CPU: {{.CPUPerc}}, Memory: {{.MemUsage}} ({{.MemPerc}}), Network I/O: {{.NetIO}}, Block I/O: {{.BlockIO}}'
  
  echo ""
  echo "🔌 Network Settings:"
  docker inspect --format '{{range $k, $v := .NetworkSettings.Ports}}{{$k}} -> {{range $v}}{{.HostIp}}:{{.HostPort}}{{end}}{{println ""}}{{end}}' ${CONTAINER_NAME}
  
  echo ""
}

# Function to show container logs
show_container_logs() {
  echo "======================================================================"
  echo "📜 CONTAINER LOGS for '${CONTAINER_NAME}' (last ${LINES} lines)"
  echo "======================================================================"
  
  # Get container logs
  docker logs --tail=${LINES} ${CONTAINER_NAME}
  
  echo ""
  echo "======================================================================"
  
  # Check for errors in logs
  echo "🔍 Checking for errors in logs:"
  ERROR_COUNT=$(docker logs ${CONTAINER_NAME} 2>&1 | grep -i -E "error|exception|fail|fatal|critical" | wc -l)
  
  if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✅ No errors found in logs!"
  else
    echo "⚠️  Found ${ERROR_COUNT} potential error entries in logs."
    echo ""
    echo "Recent errors:"
    docker logs ${CONTAINER_NAME} 2>&1 | grep -i -E "error|exception|fail|fatal|critical" | tail -n 10
  fi
}

# Main execution
check_docker
check_container_exists

if [ "$CHECK_STATS" = true ]; then
  check_container_running
  show_container_stats
fi

if [ "$CHECK_LOGS" = true ]; then
  show_container_logs
fi

echo "✅ Container check completed!" 