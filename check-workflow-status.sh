#!/bin/bash

# Script to check GitHub Actions workflow status
# Usage: ./check-workflow-status.sh

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
  
  # Try to list accessible repositories
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

# Check for workflow files
echo "Checking for workflow files..."
WORKFLOW_FILES=$(gh api repos/$REPO_PATH/actions/workflows --jq '.workflows[].name' 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$WORKFLOW_FILES" ]; then
  echo "❌ No workflow files found or not accessible"
  echo "Checking local workflow files:"
  find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null
  exit 1
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
        gh workflow run "$WORKFLOW_NAME"
      else
        echo "Workflow file not found: $WORKFLOW_PATH"
      fi
    fi
  fi
  
  exit 1
fi

echo "✅ Recent workflow runs found:"
echo "$RECENT_RUNS"

# Check permissions for downloading logs
echo "Checking permissions for downloading logs..."
FIRST_RUN_ID=$(echo "$RECENT_RUNS" | head -n 1 | cut -d '|' -f 1 | xargs)
TEST_LOGS_URL=$(gh api repos/$REPO_PATH/actions/runs/$FIRST_RUN_ID/logs -H "Accept: application/vnd.github.v3.raw" --jq ".logs_url" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$TEST_LOGS_URL" ]; then
  echo "❌ Cannot access logs - your token may not have sufficient permissions"
  echo "Try running 'gh auth refresh -s workflow' to refresh your token with workflow permissions"
else
  echo "✅ You have permissions to download logs"
fi

echo "GitHub Actions workflow status check completed." 