#!/bin/bash

# Combined script to manage GitHub Actions workflow logs
# Usage: 
#   ./workflow-logs.sh                      # View and fetch latest logs
#   ./workflow-logs.sh list                 # List recent workflow runs
#   ./workflow-logs.sh fetch [RUN_ID]       # Fetch logs for specific run ID
#   ./workflow-logs.sh status               # Check workflow status

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

# Check GitHub authentication
echo "Checking GitHub authentication..."
AUTH_STATUS=$(gh auth status 2>&1)
if [[ "$AUTH_STATUS" != *"Logged in to github.com"* ]]; then
  echo "Not authenticated with GitHub. Please run 'gh auth login' first."
  exit 1
fi
echo "✅ Authenticated with GitHub"

# Check repository existence
echo "Checking repository existence..."
REPO_INFO=$(gh repo view "$REPO_PATH" --json name 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "❌ Repository not found or not accessible: $REPO_PATH"
  echo "Listing your accessible repositories:"
  gh repo list --limit 5
  exit 1
fi
echo "✅ Repository exists and is accessible"

# Create workflow_logs directory if it doesn't exist
mkdir -p workflow_logs

# Function to check workflow status
check_workflow_status() {
  echo "Checking for workflow files..."
  WORKFLOW_FILES=$(gh api repos/$REPO_PATH/actions/workflows --jq '.workflows[].name' 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$WORKFLOW_FILES" ]; then
    echo "❌ No workflow files found or not accessible"
    echo "Checking local workflow files:"
    find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null
    return 1
  fi
  echo "✅ Workflow files found:"
  echo "$WORKFLOW_FILES"

  # Check for recent workflow runs
  echo "Checking for recent workflow runs..."
  RECENT_RUNS=$(gh api repos/$REPO_PATH/actions/runs --jq '.workflow_runs[] | "\(.id) | \(.name) | \(.status) | \(.conclusion) | \(.created_at)"' 2>/dev/null | head -n 5)
  if [ $? -ne 0 ] || [ -z "$RECENT_RUNS" ]; then
    echo "❌ No recent workflow runs found or not accessible"
    echo "This could be because:"
    echo "  - No workflows have been triggered yet"
    echo "  - Your token doesn't have sufficient permissions"
    echo "  - The repository doesn't have GitHub Actions enabled"
    
    echo "Checking if GitHub Actions is enabled for this repository..."
    ACTIONS_ENABLED=$(gh api repos/$REPO_PATH --jq '.actions_url' 2>/dev/null)
    if [ -z "$ACTIONS_ENABLED" ]; then
      echo "❌ Could not determine if GitHub Actions is enabled"
    else
      echo "✅ GitHub Actions appears to be enabled"
    fi
    
    return 1
  fi

  echo "✅ Recent workflow runs found:"
  echo "$RECENT_RUNS"

  # Check permissions for downloading logs
  echo "Checking permissions for downloading logs..."
  FIRST_RUN_ID=$(echo "$RECENT_RUNS" | head -n 1 | cut -d '|' -f 1 | xargs)
  TEST_LOGS_URL=$(gh api repos/$REPO_PATH/actions/runs/$FIRST_RUN_ID/logs -H "Accept: application/vnd.github.v3.raw" --jq ".logs_url" 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$TEST_LOGS_URL" ]; then
    echo "❌ Cannot access logs - your token may not have sufficient permissions"
    echo "Running 'gh auth refresh -s workflow' to refresh your token with workflow permissions"
    gh auth refresh -s workflow
  else
    echo "✅ You have permissions to download logs"
  fi

  echo "GitHub Actions workflow status check completed."
  return 0
}

# Function to list recent workflow runs
list_workflow_runs() {
  echo "Fetching latest workflow runs..."
  RUNS_JSON=$(gh api repos/$REPO_PATH/actions/runs 2>/dev/null)

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
    LATEST_RUN=$(gh api repos/$REPO_PATH/actions/runs --jq '.workflow_runs[0]' 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "null" ]; then
      echo "❌ No workflow runs found or not accessible."
      return 1
    fi
    
    RUN_ID=$(echo $LATEST_RUN | jq -r '.id')
    echo "Using latest run ID: $RUN_ID"
  fi

  echo "Fetching logs for workflow run $RUN_ID..."
  LOG_RESULT=$(gh api repos/$REPO_PATH/actions/runs/$RUN_ID/logs -H "Accept: application/vnd.github.v3.raw" > workflow_logs/run-$RUN_ID.zip 2>&1)

  if [ $? -ne 0 ]; then
    echo "❌ Failed to download logs: $LOG_RESULT"
    echo "This could be because:"
    echo "  - The workflow is still running"
    echo "  - Your token doesn't have sufficient permissions"
    
    echo "Refreshing token with workflow permissions..."
    gh auth refresh -s workflow
    
    echo "Retrying log download..."
    gh api repos/$REPO_PATH/actions/runs/$RUN_ID/logs -H "Accept: application/vnd.github.v3.raw" > workflow_logs/run-$RUN_ID.zip
    if [ $? -ne 0 ]; then
      echo "❌ Failed to download logs after token refresh."
      return 1
    fi
  fi

  # Check if the file is empty or not a zip file
  if [ ! -s workflow_logs/run-$RUN_ID.zip ] || ! file workflow_logs/run-$RUN_ID.zip | grep -q "Zip archive"; then
    echo "❌ Downloaded file is not a valid zip archive."
    rm workflow_logs/run-$RUN_ID.zip
    return 1
  fi

  # Extract logs
  echo "Extracting logs to workflow_logs/run-$RUN_ID..."
  mkdir -p "workflow_logs/run-$RUN_ID"
  unzip -o workflow_logs/run-$RUN_ID.zip -d "workflow_logs/run-$RUN_ID" || true  # Continue even if some files fail to extract

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
  LATEST_RUN=$(gh api repos/$REPO_PATH/actions/runs --jq '.workflow_runs[0]' 2>/dev/null)

  if [ $? -ne 0 ] || [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "null" ]; then
    echo "❌ No workflow runs found or not accessible."
    return 1
  fi

  # Extract details of the latest run
  RUN_ID=$(echo $LATEST_RUN | jq -r '.id')
  RUN_NAME=$(echo $LATEST_RUN | jq -r '.name')
  RUN_STATUS=$(echo $LATEST_RUN | jq -r '.status')
  RUN_CONCLUSION=$(echo $LATEST_RUN | jq -r '.conclusion')
  RUN_DATE=$(echo $LATEST_RUN | jq -r '.created_at')

  echo "Latest workflow run:"
  echo "ID: $RUN_ID"
  echo "Name: $RUN_NAME"
  echo "Status: $RUN_STATUS"
  echo "Conclusion: $RUN_CONCLUSION"
  echo "Created: $RUN_DATE"

  # Fetch the jobs for this run
  echo "Fetching jobs for workflow run $RUN_ID..."
  JOBS=$(gh api repos/$REPO_PATH/actions/runs/$RUN_ID/jobs 2>/dev/null)

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

# Main functionality based on arguments
case "$1" in
  "list")
    list_workflow_runs
    ;;
  "fetch")
    fetch_run_logs "$2"
    ;;
  "status")
    check_workflow_status
    ;;
  *)
    # Default action: view and fetch latest logs
    view_latest_run
    ;;
esac 