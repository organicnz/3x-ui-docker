#!/bin/bash

# Source utility functions and color variables
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
else
  echo -e "\033[0;31mError: utils.sh not found. Please ensure it exists in the scripts directory.\033[0m"
  exit 1
fi

# Check if act is installed (GitHub Actions local runner)
if ! command -v act &> /dev/null; then
    echo -e "${RED}The 'act' tool is not installed. Please install it first:${NC}"
    echo -e "macOS: ${YELLOW}brew install act${NC}"
    echo -e "Other: ${YELLOW}https://github.com/nektos/act#installation${NC}"
    exit 1
fi

echo -e "${BLUE}==== Testing GitHub Actions Workflow Locally ====${NC}"

# Workflow file path
WORKFLOW_FILE=".github/workflows/3x-ui-workflow.yml"

# Check if workflow file exists
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${RED}Workflow file not found: ${WORKFLOW_FILE}${NC}"
    exit 1
fi

# List available workflows
echo -e "${BLUE}Available workflow jobs:${NC}"
act -l | grep -v "Stage" | grep -v "^$" | awk '{print $3}' | sort | uniq | while read -r job; do
    echo "  - ${job}"
done

# Ask which job to run
echo -e "\n${YELLOW}Which job would you like to test? (e.g., debug_info, validate, etc.)${NC}"
read JOB_NAME

if [ -z "$JOB_NAME" ]; then
    echo -e "${RED}No job name provided. Exiting.${NC}"
    exit 1
fi

# Check if the job exists
if ! act -l | grep -q "$JOB_NAME"; then
    echo -e "${RED}Job '${JOB_NAME}' not found in the workflow.${NC}"
    echo -e "${YELLOW}Available jobs:${NC}"
    act -l | grep -v "Stage" | grep -v "^$" | awk '{print "  - " $3}'
    exit 1
fi

# Ask for dry run
echo -e "\n${YELLOW}Perform a dry run? (y/n, default: y)${NC}"
read DRY_RUN
DRY_RUN=${DRY_RUN:-y}

# Run the workflow
echo -e "${BLUE}Running job '${JOB_NAME}'...${NC}"

# Set up environment variables if .env exists
ENV_VARS=""
if [ -f ".env" ]; then
    echo -e "${GREEN}Using environment variables from .env${NC}"
    ENV_VARS=$(grep -v '^#' .env | sed 's/^/-e /' | tr '\n' ' ')
fi

if [[ "$DRY_RUN" == "y" || "$DRY_RUN" == "Y" ]]; then
    echo -e "${YELLOW}Dry run - command would be:${NC}"
    echo "act -j $JOB_NAME --dryrun $ENV_VARS"
else
    echo -e "${GREEN}Executing job...${NC}"
    # shellcheck disable=SC2086
    act -j "$JOB_NAME" $ENV_VARS
fi

echo -e "\n${GREEN}Workflow test complete!${NC}" 