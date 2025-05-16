#!/bin/bash

# Combined script to manage GitHub Actions workflow logs without interactive prompts
# Usage: 
#   ./workflow-logs.sh [token] [command]                # Commands: list, fetch, status
#   GITHUB_TOKEN=your_token ./workflow-logs.sh [command] # Alternative using env var

# Default command if none provided
COMMAND="${2:-latest}"

# Check for token in environment variable or first argument
if [ -n "$GITHUB_TOKEN" ]; then
  TOKEN="$GITHUB_TOKEN"
elif [ -n "$1" ] && [[ "$1" != "list" && "$1" != "fetch" && "$1" != "status" && "$1" != "latest" ]]; then
  TOKEN="$1"
  # If first arg is token, shift args so the command becomes $1
  if [ -n "$2" ]; then
    COMMAND="$2"
  fi
else
  # No token provided in args or env, use command as $1
  COMMAND="${1:-latest}"
  
  # Check if gh is already authenticated
  AUTH_STATUS=$(gh auth status 2>&1)
  if [[ "$AUTH_STATUS" != *"Logged in to github.com"* ]]; then
    echo "❌ No GitHub token provided and not authenticated with GitHub CLI."
    echo "Please provide a token as the first argument or via GITHUB_TOKEN environment variable:"
    echo "  ./workflow-logs.sh YOUR_TOKEN"
    echo "  GITHUB_TOKEN=YOUR_TOKEN ./workflow-logs.sh"
    exit 1
  else
    echo "✅ Using existing GitHub CLI authentication"
    USE_GH_CLI=true
  fi
fi

# Get repository information from git remote
REPO_URL=$(git remote get-url origin)
echo "Repository URL: $REPO_URL"

# Extract owner and repo name
if [[ "$REPO_URL" =~ github.com[/:]([^/]+)/([^/]+)(\.git)? ]]; then
  REPO_OWNER="${BASH_REMATCH[1]}"
  REPO_NAME="${BASH_REMATCH[2]}"
  REPO_NAME="${REPO_NAME%.git}"  # Remove .git suffix if present
  REPO_PATH="$REPO_OWNER/$REPO_NAME"
else
  echo "Could not parse repository information from URL: $REPO_URL"
  echo "Using repository path from remote URL as is"
  REPO_PATH=$(echo $REPO_URL | sed -E 's/.*github\.com[\/:]([^\/]+\/[^\/]+)(\.git)?$/\1/')
fi

echo "Repository: $REPO_PATH"

# Create workflow_logs directory if it doesn't exist
mkdir -p workflow_logs

# Function to make API calls with token or via GH CLI
github_api() {
  local endpoint="$1"
  local accept_header="${2:-application/vnd.github.v3+json}"
  local output_file="$3"
  
  if [ "$USE_GH_CLI" = true ]; then
    if [ -n "$output_file" ]; then
      gh api "$endpoint" -H "Accept: $accept_header" > "$output_file" 2>/dev/null
      return $?
    else
      gh api "$endpoint" -H "Accept: $accept_header" 2>/dev/null
      return $?
    fi
  else
    if [ -n "$output_file" ]; then
      curl -s -H "Authorization: token $TOKEN" -H "Accept: $accept_header" "https://api.github.com/$endpoint" > "$output_file"
      return $?
    else
      curl -s -H "Authorization: token $TOKEN" -H "Accept: $accept_header" "https://api.github.com/$endpoint"
      return $?
    fi
  fi
}

# Function to check workflow status
check_workflow_status() {
  echo "Checking for workflow files..."
  WORKFLOW_FILES=$(github_api "repos/$REPO_PATH/actions/workflows")
  
  if [ $? -ne 0 ] || [ -z "$WORKFLOW_FILES" ]; then
    echo "❌ No workflow files found or not accessible"
    echo "Checking local workflow files:"
    find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null
    return 1
  fi
  
  echo "✅ Workflow files found:"
  echo "$WORKFLOW_FILES" | jq -r '.workflows[].name' 2>/dev/null

  # Check for recent workflow runs
  echo "Checking for recent workflow runs..."
  RECENT_RUNS=$(github_api "repos/$REPO_PATH/actions/runs")
  
  if [ $? -ne 0 ] || [ -z "$RECENT_RUNS" ] || ! echo "$RECENT_RUNS" | jq -e '.workflow_runs[0]' &>/dev/null; then
    echo "❌ No recent workflow runs found or not accessible"
    echo "This could be because:"
    echo "  - No workflows have been triggered yet"
    echo "  - Your token doesn't have sufficient permissions"
    echo "  - The repository doesn't have GitHub Actions enabled"
    
    return 1
  fi

  echo "✅ Recent workflow runs found:"
  echo "$RECENT_RUNS" | jq -r '.workflow_runs[] | "\(.id) | \(.name) | \(.status) | \(.conclusion) | \(.created_at)"' | head -n 5

  echo "GitHub Actions workflow status check completed."
  return 0
}

# Function to list recent workflow runs
list_workflow_runs() {
  echo "Fetching latest workflow runs..."
  RUNS_JSON=$(github_api "repos/$REPO_PATH/actions/runs")

  # Check if there are any workflow runs
  if [ $? -ne 0 ] || [ -z "$RUNS_JSON" ] || [ "$RUNS_JSON" = "null" ] || ! echo "$RUNS_JSON" | jq -e '.workflow_runs[0]' &>/dev/null; then
    echo "❌ No workflow runs found or unable to fetch workflow data."
    return 1
  fi

  # Parse and display workflow runs
  echo "Latest workflow runs:"
  echo "$RUNS_JSON" | jq -r '.workflow_runs[] | "\(.id) | \(.name) | \(.status) | \(.conclusion) | \(.created_at)"' | head -n 10
  return 0
}

# Function to fetch logs for a specific run
fetch_run_logs() {
  RUN_ID=$1
  
  if [ -z "$RUN_ID" ]; then
    echo "No run ID specified, fetching logs for latest run..."
    LATEST_RUN=$(github_api "repos/$REPO_PATH/actions/runs")
    
    if [ $? -ne 0 ] || [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "null" ]; then
      echo "❌ No workflow runs found or not accessible."
      return 1
    fi
    
    RUN_ID=$(echo $LATEST_RUN | jq -r '.workflow_runs[0].id')
    echo "Using latest run ID: $RUN_ID"
  fi

  echo "Fetching logs for workflow run $RUN_ID..."
  LOG_PATH="workflow_logs/run-$RUN_ID.zip"
  
  github_api "repos/$REPO_PATH/actions/runs/$RUN_ID/logs" "application/vnd.github.v3.raw" "$LOG_PATH"

  if [ $? -ne 0 ] || [ ! -s "$LOG_PATH" ]; then
    echo "❌ Failed to download logs."
    echo "This could be because:"
    echo "  - The workflow is still running"
    echo "  - Your token doesn't have sufficient permissions (needs workflow scope)"
    echo "  - The run ID doesn't exist"
    
    rm -f "$LOG_PATH" 2>/dev/null
    return 1
  fi

  # Check if the file is empty or not a zip file
  if ! file "$LOG_PATH" | grep -q "Zip archive"; then
    echo "❌ Downloaded file is not a valid zip archive."
    rm -f "$LOG_PATH"
    return 1
  fi

  # Extract logs
  echo "Extracting logs to workflow_logs/run-$RUN_ID..."
  mkdir -p "workflow_logs/run-$RUN_ID"
  unzip -o "$LOG_PATH" -d "workflow_logs/run-$RUN_ID" || true  # Continue even if some files fail to extract

  echo "Logs extracted successfully. Check workflow_logs/run-$RUN_ID directory for log files."
  echo "Showing available log files:"
  find "workflow_logs/run-$RUN_ID" -type f | sort

  # Create a symlink to the latest logs
  rm -f workflow_logs/run-latest
  ln -sf "run-$RUN_ID" workflow_logs/run-latest

  echo "You can view the logs with 'cat workflow_logs/run-latest/<log_file>'"
  return 0
}

# Function to get detailed info about the latest run
view_latest_run() {
  echo "Fetching latest workflow run..."
  LATEST_RUN=$(github_api "repos/$REPO_PATH/actions/runs")

  if [ $? -ne 0 ] || [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "null" ]; then
    echo "❌ No workflow runs found or not accessible."
    return 1
  fi

  # Extract details of the latest run
  RUN_ID=$(echo $LATEST_RUN | jq -r '.workflow_runs[0].id')
  RUN_NAME=$(echo $LATEST_RUN | jq -r '.workflow_runs[0].name')
  RUN_STATUS=$(echo $LATEST_RUN | jq -r '.workflow_runs[0].status')
  RUN_CONCLUSION=$(echo $LATEST_RUN | jq -r '.workflow_runs[0].conclusion')
  RUN_DATE=$(echo $LATEST_RUN | jq -r '.workflow_runs[0].created_at')

  echo "Latest workflow run:"
  echo "ID: $RUN_ID"
  echo "Name: $RUN_NAME"
  echo "Status: $RUN_STATUS"
  echo "Conclusion: $RUN_CONCLUSION"
  echo "Created: $RUN_DATE"

  # Fetch the jobs for this run
  echo "Fetching jobs for workflow run $RUN_ID..."
  JOBS=$(github_api "repos/$REPO_PATH/actions/runs/$RUN_ID/jobs")

  if [ $? -eq 0 ] && [ -n "$JOBS" ] && [ "$JOBS" != "null" ]; then
    # Display jobs
    echo "Jobs in this workflow run:"
    echo $JOBS | jq -r '.jobs[] | "\(.id) | \(.name) | \(.status) | \(.conclusion)"' || echo "No job information available"
  else
    echo "❌ Could not fetch job information."
  fi

  # Always fetch logs for the latest run
  fetch_run_logs $RUN_ID
  return 0
}

# Main functionality based on command
case "$COMMAND" in
  "list")
    list_workflow_runs
    ;;
  "fetch")
    if [ -n "$3" ]; then
      fetch_run_logs "$3"
    else
      fetch_run_logs
    fi
    ;;
  "status")
    check_workflow_status
    ;;
  "latest"|*)
    # Default action: view and fetch latest logs
    view_latest_run
    ;;
esac 