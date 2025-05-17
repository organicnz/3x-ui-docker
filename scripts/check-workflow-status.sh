#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables from .env file
if [ -f ".env" ]; then
  source .env
else
  echo -e "${YELLOW}No .env file found. Consider creating one with ./scripts/setup-env.sh${NC}"
fi

# Repository information
REPO_OWNER=${REPO_OWNER:-"organicnz"}
REPO_NAME=${REPO_NAME:-"3x-ui-docker"}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

# Function to display usage instructions
function show_help {
  echo -e "${BLUE}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${BLUE}Options:${NC}"
  echo -e "  -h, --help     Show this help message"
  echo -e "  -l, --limit N  Show N most recent workflow runs (default: 5)"
  echo -e "  -a, --all      Show all workflow runs"
  echo -e ""
  echo -e "${BLUE}Requirements:${NC}"
  echo -e "  - GitHub token with 'repo' or 'workflow' scope in .env file"
  echo -e "  - 'curl' and 'jq' installed"
  echo -e ""
}

# Check if curl and jq are installed
if ! command -v curl &> /dev/null; then
  echo -e "${RED}Error: curl is not installed. Please install it first.${NC}"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is not installed. Please install it:${NC}"
  echo -e "  ${BLUE}brew install jq${NC} (for macOS)"
  echo -e "  ${BLUE}apt-get install jq${NC} (for Ubuntu/Debian)"
  exit 1
fi

# Parse command line arguments
LIMIT=5
SHOW_ALL=false

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -l|--limit)
      shift
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        LIMIT=$1
      else
        echo -e "${RED}Error: Invalid limit value. Must be a number.${NC}"
        exit 1
      fi
      ;;
    -a|--all)
      SHOW_ALL=true
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_help
      exit 1
      ;;
  esac
  shift
done

# Check if we have a GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
  echo -e "${YELLOW}No GitHub token found in .env file.${NC}"
  echo -e "GitHub API requests will be rate-limited. Consider adding a token to your .env file:"
  echo -e "  GITHUB_TOKEN=your_personal_access_token"
  echo -e ""
  AUTH_HEADER=""
else
  AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
fi

# Fetch workflow runs
echo -e "${BLUE}Fetching workflow runs for ${REPO_OWNER}/${REPO_NAME}...${NC}"

API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runs"
if [ "$SHOW_ALL" = false ]; then
  API_URL="${API_URL}?per_page=${LIMIT}"
fi

RESPONSE=$(curl -s -H "Accept: application/vnd.github.v3+json" ${AUTH_HEADER:+-H "$AUTH_HEADER"} "${API_URL}")

# Check if the request was successful
if [[ $(echo "$RESPONSE" | jq -r 'has("message")') == "true" ]]; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message')
  echo -e "${RED}Error fetching workflow runs: ${ERROR_MSG}${NC}"
  exit 1
fi

# Extract and display workflow runs
WORKFLOW_COUNT=$(echo "$RESPONSE" | jq -r '.workflow_runs | length')

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}No workflow runs found for ${REPO_OWNER}/${REPO_NAME}.${NC}"
  exit 0
fi

echo -e "${GREEN}Found ${WORKFLOW_COUNT} workflow runs:${NC}"
echo

# Get the length of the longest workflow name for formatting
MAX_NAME_LENGTH=$(echo "$RESPONSE" | jq -r '.workflow_runs[].name' | wc -L)
MAX_NAME_LENGTH=$((MAX_NAME_LENGTH < 10 ? 10 : MAX_NAME_LENGTH))

# Header
printf "%-${MAX_NAME_LENGTH}s | %-10s | %-20s | %-20s | %s\n" "WORKFLOW" "STATUS" "BRANCH" "TRIGGERED" "URL"
printf "%${MAX_NAME_LENGTH}s-|-%10s-|-%20s-|-%20s-|-%s\n" | tr ' ' '-'

# Rows
echo "$RESPONSE" | jq -r '.workflow_runs[] | [.name, .conclusion // "running", .head_branch, .created_at, .html_url] | @tsv' | \
while IFS=$'\t' read -r NAME STATUS BRANCH CREATED_AT URL; do
  # Convert the status to a colored output
  STATUS_COLOR=""
  case "$STATUS" in
    "success")
      STATUS_COLOR="${GREEN}✓ success${NC}"
      ;;
    "failure")
      STATUS_COLOR="${RED}✗ failure${NC}"
      ;;
    "running")
      STATUS_COLOR="${BLUE}⟳ running${NC}"
      ;;
    "cancelled")
      STATUS_COLOR="${YELLOW}⊘ canceled${NC}"
      ;;
    *)
      STATUS_COLOR="${YELLOW}? ${STATUS}${NC}"
      ;;
  esac
  
  # Format the date to be more readable
  FORMATTED_DATE=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED_AT" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
  if [ $? -ne 0 ]; then
    # Try an alternative format for Linux
    FORMATTED_DATE=$(date -d "$CREATED_AT" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    if [ $? -ne 0 ]; then
      FORMATTED_DATE="$CREATED_AT"
    fi
  fi
  
  # Print the row
  printf "%-${MAX_NAME_LENGTH}s | %-56s | %-20s | %-20s | %s\n" "$NAME" "$STATUS_COLOR" "$BRANCH" "$FORMATTED_DATE" "$URL"
done

echo
echo -e "${BLUE}For detailed logs, visit the workflow URLs above or use:${NC}"
echo -e "  ${GREEN}./scripts/workflow-logs.sh -g${NC}  (for GitHub Actions instructions)"
echo -e "  ${GREEN}./scripts/workflow-logs.sh -f${NC}  (to fetch remote logs)" 