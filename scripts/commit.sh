#!/bin/bash

# Source utility functions and color variables
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
else
  echo "\033[0;31mError: utils.sh not found. Please ensure it exists in the scripts directory.\033[0m"
  exit 1
fi

# Define valid commit types
VALID_TYPES=("Feat" "Fix" "Docs" "Refactor" "Style" "Test" "Chore")

# Default values
DEFAULT_TYPE="Chore"
DEFAULT_DESC="update project files"

# Function to display usage
function show_help {
  echo -e "${BLUE}Usage:${NC}"
  echo -e "  $0 [options] \"message\" \"type\""
  echo -e ""
  echo -e "${BLUE}Arguments:${NC}"
  echo -e "  message    Commit message (required)"
  echo -e "  type       Commit type (e.g., Feat, Fix, Docs, etc.) (required)"
  echo -e ""
  echo -e "${BLUE}Options:${NC}"
  echo -e "  -h, --help     Show this help message"
  echo -e "  -y, --yes      Skip confirmation prompt and automatically commit"
  echo -e ""
  echo -e "${BLUE}Valid types:${NC}"
  for type in "${VALID_TYPES[@]}"; do
    echo -e "  ${type}"
  done
  echo -e ""
  echo -e "${BLUE}Examples:${NC}"
  echo -e "  $0 \"add dark mode toggle\" \"Feat\""
  echo -e "  $0 -y \"fix user authentication bug\" \"Fix\""
  echo -e ""
}

# Function to detect scope based on changed files (merged logic)
function detect_scope {
  changed_files=$(git diff --name-only --cached)
  scope="app" # Default scope
  if echo "$changed_files" | grep -q "^components/"; then
    scope="component"
  elif echo "$changed_files" | grep -q "^api/"; then
    scope="api"
  elif echo "$changed_files" | grep -q "^utils/"; then
    scope="utils"
  elif echo "$changed_files" | grep -q "^public/"; then
    scope="assets"
  elif echo "$changed_files" | grep -q "^styles/"; then
    scope="styles"
  elif echo "$changed_files" | grep -q "^pages/"; then
    scope="page"
  elif echo "$changed_files" | grep -q "^.github/"; then
    scope="workflow"
  elif echo "$changed_files" | grep -q "^scripts/"; then
    scope="scripts"
  elif echo "$changed_files" | grep -q "^tests/"; then
    scope="test"
  elif echo "$changed_files" | grep -q "docker-compose"; then
    scope="docker"
  elif echo "$changed_files" | grep -q "package.json\|yarn.lock\|package-lock.json"; then
    scope="deps"
  elif echo "$changed_files" | grep -q "README.md\|LICENSE\|CONTRIBUTING.md\|\.md$"; then
    scope="docs"
  else
    scope="vpn"
  fi
  echo "$scope"
}

# Function to validate commit type
function validate_type {
  local type=$1
  for valid_type in "${VALID_TYPES[@]}"; do
    if [[ "$valid_type" == "$type" ]]; then
      return 0
    fi
  done
  return 1
}

# Parse command line options
AUTO_CONFIRM=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -y|--yes)
      AUTO_CONFIRM=true
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Interactive mode if no arguments provided
if [ $# -eq 0 ]; then
  echo -e "${YELLOW}Running commit script in interactive mode...${NC}"
  echo -e "${BLUE}Valid commit types:${NC}"
  for i in "${!VALID_TYPES[@]}"; do
    echo -e "  $((i+1)). ${VALID_TYPES[$i]}"
  done
  echo -e "${YELLOW}Enter commit message:${NC}"
  read -r commit_message
  if [ -z "$commit_message" ]; then
    echo -e "${RED}Error: Commit message cannot be empty.${NC}"
    exit 1
  fi
  echo -e "${YELLOW}Select commit type (enter number):${NC}"
  read -r type_number
  if ! [[ "$type_number" =~ ^[0-9]+$ ]] || [ "$type_number" -lt 1 ] || [ "$type_number" -gt ${#VALID_TYPES[@]} ]; then
    echo -e "${RED}Error: Invalid selection. Please enter a number between 1 and ${#VALID_TYPES[@]}.${NC}"
    exit 1
  fi
  commit_type="${VALID_TYPES[$((type_number-1))]}"
else
  # Direct mode with arguments
  if [ $# -lt 2 ]; then
    commit_message="${1:-$DEFAULT_DESC}"
    commit_type="${2:-$DEFAULT_TYPE}"
  else
    commit_message=$1
    commit_type=$2
  fi
  # Validate commit type
  if ! validate_type "$commit_type"; then
    echo -e "${RED}Error: Invalid commit type '$commit_type'.${NC}"
    echo -e "${YELLOW}Valid types are: ${VALID_TYPES[*]}${NC}"
    exit 1
  fi
  AUTO_CONFIRM=true # Always auto-confirm in direct mode
fi

# Stage all changes
git add .

# Detect the scope based on changed files
scope=$(detect_scope)

# Format the commit message
formatted_message="${commit_type}(${scope}): ${commit_message}"

# Show the commit message
echo -e "${BLUE}Commit message will be:${NC} ${formatted_message}"
if [ "$AUTO_CONFIRM" = false ]; then
  echo -e "${YELLOW}Proceed with commit? (y/n)${NC}"
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo -e "${RED}Commit aborted.${NC}"
    exit 0
  fi
fi

# Execute the commit
echo -e "${GREEN}Committing changes...${NC}"
git commit -m "$formatted_message"

# Push the changes
echo -e "${GREEN}Pushing changes...${NC}"
git push --set-upstream origin main

echo -e "${GREEN}Changes committed and pushed successfully!${NC}" 