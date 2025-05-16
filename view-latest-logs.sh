#!/bin/bash

# Script to view the latest GitHub Actions logs
# Usage: ./view-latest-logs.sh

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
  echo "Manually enter repository owner/name (e.g., octocat/hello-world):"
  read REPO_PATH
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
  
  echo "Would you like to specify a different repository? (y/n)"
  read CHANGE_REPO
  
  if [ "$CHANGE_REPO" = "y" ]; then
    echo "Enter repository owner/name (e.g., octocat/hello-world):"
    read REPO_PATH
    
    # Check if the new repo is accessible
    REPO_INFO=$(gh repo view "$REPO_PATH" --json name 2>/dev/null)
    if [ $? -ne 0 ]; then
      echo "❌ Repository still not accessible: $REPO_PATH"
      exit 1
    fi
    echo "✅ Repository exists and is accessible: $REPO_PATH"
  else
    exit 1
  fi
else
  echo "✅ Repository exists and is accessible"
fi

# Fetch the latest workflow run
echo "Fetching latest workflow run..."
LATEST_RUN=$(gh api repos/$REPO_PATH/actions/runs --jq '.workflow_runs[0]' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "null" ]; then
  echo "❌ No workflow runs found or not accessible."
  echo "This could be because:"
  echo "  - No workflows have been triggered yet"
  echo "  - Your token doesn't have sufficient permissions"
  
  echo "Would you like to manually trigger a workflow? (y/n)"
  read TRIGGER_WORKFLOW
  
  if [ "$TRIGGER_WORKFLOW" = "y" ]; then
    echo "Available workflows:"
    WORKFLOWS=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null)
    if [ -z "$WORKFLOWS" ]; then
      echo "No workflow files found locally."
    else
      echo "$WORKFLOWS"
      echo "Enter the workflow file path to trigger (e.g. .github/workflows/main.yml):"
      read WORKFLOW_PATH
      
      if [ -f "$WORKFLOW_PATH" ]; then
        WORKFLOW_NAME=$(basename "$WORKFLOW_PATH")
        echo "Triggering workflow: $WORKFLOW_NAME"
        gh workflow run "$WORKFLOW_NAME" -R "$REPO_PATH"
        
        echo "Workflow triggered. Wait for it to start and then run this script again."
      else
        echo "Workflow file not found: $WORKFLOW_PATH"
      fi
    fi
  fi
  
  exit 1
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

# Create workflow_logs directory if it doesn't exist
mkdir -p workflow_logs

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

# Ask if user wants to see the logs
echo "Do you want to download the logs for this run? (y/n)"
read DOWNLOAD_LOGS

if [ "$DOWNLOAD_LOGS" = "y" ]; then
  # Fetch the logs for this run
  echo "Downloading logs for workflow run $RUN_ID..."
  LOG_RESULT=$(gh api repos/$REPO_PATH/actions/runs/$RUN_ID/logs -H "Accept: application/vnd.github.v3.raw" > workflow_logs/run-$RUN_ID.zip 2>&1)
  
  if [ $? -ne 0 ]; then
    echo "❌ Failed to download logs: $LOG_RESULT"
    echo "This could be because:"
    echo "  - The workflow is still running"
    echo "  - Your token doesn't have sufficient permissions"
    echo "Try running 'gh auth refresh -s workflow' to refresh your token with workflow permissions"
    exit 1
  fi
  
  # Check if the file is empty or not a zip file
  if [ ! -s workflow_logs/run-$RUN_ID.zip ] || ! file workflow_logs/run-$RUN_ID.zip | grep -q "Zip archive"; then
    echo "❌ Downloaded file is not a valid zip archive."
    rm workflow_logs/run-$RUN_ID.zip
    exit 1
  fi
  
  # Extract logs
  echo "Extracting logs to workflow_logs/run-$RUN_ID..."
  mkdir -p "workflow_logs/run-$RUN_ID"
  unzip -o workflow_logs/run-$RUN_ID.zip -d "workflow_logs/run-$RUN_ID"
  
  echo "Logs extracted successfully. Available log files:"
  find "workflow_logs/run-$RUN_ID" -type f | sort
  
  # Create a symlink to the latest logs
  rm -f workflow_logs/run-latest
  ln -sf "run-$RUN_ID" workflow_logs/run-latest
  
  echo "You can view the logs with 'cat workflow_logs/run-latest/<log_file>'"
fi 