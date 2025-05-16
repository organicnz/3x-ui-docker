#!/bin/bash

# Auto-commit script that doesn't ask for permission
# Usage: ./auto-commit.sh "description of changes" "Type"
# Example: ./auto-commit.sh "add dark mode toggle" "Feat"

# Default values
DEFAULT_TYPE="Chore"
DEFAULT_DESC="update project files"

# Function to determine scope based on modified files
determine_scope() {
  # Check which files are modified
  if git diff --name-only --cached | grep -q "docker-compose"; then
    echo "docker"
  elif git diff --name-only --cached | grep -q "\.github/workflows"; then
    echo "workflow"
  elif git diff --name-only --cached | grep -q "\.md$"; then
    echo "docs"
  elif git diff --name-only --cached | grep -q "package.json\|yarn.lock\|package-lock.json"; then
    echo "deps"
  else
    echo "vpn"  # Default scope
  fi
}

# Get description and type from arguments
DESCRIPTION="${1:-$DEFAULT_DESC}"
TYPE="${2:-$DEFAULT_TYPE}"

# Add all files to git staging
git add .

# Determine scope from modified files
SCOPE=$(determine_scope)

# Format the commit message
COMMIT_MESSAGE="${TYPE}(${SCOPE}): ${DESCRIPTION}"

# Show the commit message
echo -e "\nCommit message: $COMMIT_MESSAGE"
echo -e "Proceeding with commit..."

# Perform commit
git commit -m "$COMMIT_MESSAGE"

# Push changes
git push --set-upstream origin main

echo -e "\n✅ Changes committed and pushed successfully!" 