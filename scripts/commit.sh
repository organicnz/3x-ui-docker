#!/bin/bash

# Auto-commit script based on team's commit rules
# Usage: ./commit.sh "description of changes" "Type"
# Example: ./commit.sh "add dark mode toggle" "Feat"

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

# Check if we have the right number of arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Starting interactive mode..."
  
  # Ask for commit message
  echo "Enter your commit message (without type and scope):"
  read DESCRIPTION
  
  # Show commit types
  echo -e "\nCommit types:"
  echo "1. Feat: New feature or functionality"
  echo "2. Fix: Bug fix"
  echo "3. Docs: Documentation changes"
  echo "4. Refactor: Code changes that neither fix bugs nor add features"
  echo "5. Style: Changes related to styling or formatting"
  echo "6. Test: Adding or updating tests"
  echo "7. Chore: Maintenance tasks, dependency updates, etc."
  
  # Ask for commit type
  echo -e "\nEnter the number of your commit type:"
  read TYPE_NUMBER
  
  # Convert number to type
  case $TYPE_NUMBER in
    1) TYPE="Feat" ;;
    2) TYPE="Fix" ;;
    3) TYPE="Docs" ;;
    4) TYPE="Refactor" ;;
    5) TYPE="Style" ;;
    6) TYPE="Test" ;;
    7) TYPE="Chore" ;;
    *) 
      echo "Invalid selection. Using 'Chore' as default."
      TYPE="Chore"
      ;;
  esac
else
  # Direct mode
  DESCRIPTION="$1"
  
  if [ "$#" -eq 2 ]; then
    TYPE="$2"
  else
    # Default type if only description is provided
    TYPE="Chore"
  fi
fi

# Add all files to git staging
git add .

# Determine scope from modified files
SCOPE=$(determine_scope)

# Format the commit message
COMMIT_MESSAGE="${TYPE}(${SCOPE}): ${DESCRIPTION}"

# Show the commit message and proceed automatically
echo -e "\nCommit message: $COMMIT_MESSAGE"
echo -e "Proceeding with commit automatically..."

# Perform commit
git commit -m "$COMMIT_MESSAGE"

# Push changes
git push --set-upstream origin main

echo -e "\n✅ Changes committed and pushed successfully!" 