#!/bin/bash

# Script to check both remote server and GitHub workflow errors
# Usage: ./check-errors.sh [--server] [--workflow] [--all]

set -e

# Default values
CHECK_SERVER=false
CHECK_WORKFLOW=false
SERVER_ARGS=""
WORKFLOW_ARGS=""

# Parse arguments
for arg in "$@"; do
  case $arg in
    --server)
      CHECK_SERVER=true
      shift
      ;;
    --workflow)
      CHECK_WORKFLOW=true
      shift
      ;;
    --all)
      CHECK_SERVER=true
      CHECK_WORKFLOW=true
      shift
      ;;
    --server-*)
      SERVER_ARGS+=" $arg"
      shift
      ;;
    --workflow-*)
      # Convert workflow-* args to the format expected by check-workflow-logs.sh
      NEW_ARG=$(echo $arg | sed 's/--workflow-/--/')
      WORKFLOW_ARGS+=" $NEW_ARG"
      shift
      ;;
    --lines=*)
      SERVER_ARGS+=" $arg"
      shift
      ;;
    --run-id=*)
      WORKFLOW_ARGS+=" $arg"
      shift
      ;;
    --help)
      echo "Usage: ./check-errors.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --server              Check server errors"
      echo "  --workflow            Check GitHub workflow errors"
      echo "  --all                 Check both server and workflow errors (default)"
      echo "  --server-full         Show full server logs"
      echo "  --server-all          Show all server log entries"
      echo "  --lines=N             Show last N lines of logs"
      echo "  --workflow-latest     Check latest workflow run"
      echo "  --run-id=<id>         Check specific run ID"
      echo "  --help                Show this help message"
      exit 0
      ;;
  esac
done

# If no specific check is requested, check all
if [ "$CHECK_SERVER" = false ] && [ "$CHECK_WORKFLOW" = false ]; then
  CHECK_SERVER=true
  CHECK_WORKFLOW=true
fi

# Function to check if a script exists and is executable
check_script() {
  if [ ! -f "$1" ] || [ ! -x "$1" ]; then
    echo "❌ Error: Script $1 not found or not executable!"
    echo "   Run: chmod +x $1"
    return 1
  fi
  return 0
}

# Check server errors
if [ "$CHECK_SERVER" = true ]; then
  echo "======================================================================"
  echo "🖥️  CHECKING SERVER ERRORS"
  echo "======================================================================"
  
  if check_script "./scripts/check-remote-errors.sh"; then
    ./scripts/check-remote-errors.sh $SERVER_ARGS
  fi
  
  echo ""
fi

# Check workflow errors
if [ "$CHECK_WORKFLOW" = true ]; then
  echo "======================================================================"
  echo "🔄 CHECKING GITHUB WORKFLOW ERRORS"
  echo "======================================================================"
  
  if check_script "./scripts/check-workflow-logs.sh"; then
    ./scripts/check-workflow-logs.sh $WORKFLOW_ARGS
  fi
  
  echo ""
fi

echo "✅ Error checking completed!" 