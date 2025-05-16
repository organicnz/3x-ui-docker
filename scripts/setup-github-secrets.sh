#!/bin/bash

# Script to upload environment variables from .env to GitHub Actions secrets
# Usage: ./setup-github-secrets.sh

# Check for GitHub CLI installation
if ! command -v gh &> /dev/null; then
  echo "GitHub CLI (gh) is not installed. Please install it first:"
  echo "https://cli.github.com/manual/installation"
  exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
  echo "No .env file found. Please create one first."
  exit 1
fi

# Load repository information
REPO_URL=$(git remote get-url origin)
if [[ "$REPO_URL" =~ github.com[/:]([^/]+)/([^/]+)(\.git)? ]]; then
  REPO_OWNER="${BASH_REMATCH[1]}"
  REPO_NAME="${BASH_REMATCH[2]}"
  REPO_NAME="${REPO_NAME%.git}"  # Remove .git suffix if present
  REPO_PATH="$REPO_OWNER/$REPO_NAME"
else
  echo "Could not parse repository information from URL: $REPO_URL"
  echo "Please enter the repository path manually (e.g., octocat/hello-world):"
  read REPO_PATH
fi

echo "Repository: $REPO_PATH"

# Check authentication
AUTH_STATUS=$(gh auth status 2>&1)
if [[ "$AUTH_STATUS" != *"Logged in to github.com"* ]]; then
  echo "Not authenticated with GitHub. Please run 'gh auth login' first."
  exit 1
fi

# Extract variables from .env file (ignore comments and empty lines)
echo "Reading variables from .env file..."
VARS=$(grep -v '^#' .env | grep -v '^$')

# Set each variable as a GitHub secret
echo "Setting GitHub secrets..."
echo "$VARS" | while IFS= read -r line; do
  if [[ "$line" == *"="* ]]; then
    KEY=$(echo "$line" | cut -d= -f1)
    VALUE=$(echo "$line" | cut -d= -f2-)
    
    echo "Setting secret: $KEY"
    echo "$VALUE" | gh secret set "$KEY" -R "$REPO_PATH"
    
    if [ $? -eq 0 ]; then
      echo "✅ Successfully set $KEY"
    else
      echo "❌ Failed to set $KEY"
    fi
  fi
done

echo "All secrets have been set successfully!"
echo "These secrets are now available for use in your GitHub Actions workflows." 