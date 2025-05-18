#!/bin/bash

# Source utility functions and color variables
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
else
  echo "\033[0;31mError: utils.sh not found. Please ensure it exists in the scripts directory.\033[0m"
  exit 1
fi

echo -e "${BLUE}Opening 3x-ui VPN admin panel...${NC}"

# Check if the container is running
if ! docker ps | grep -q "3x-ui"; then
  echo -e "${RED}Error: Container 3x-ui is not running. Starting it...${NC}"
  docker-compose up -d
  echo -e "${YELLOW}Waiting for the container to start...${NC}"
  sleep 5
fi

# Define the panel URL
PANEL_URL="https://localhost:54321/BXv8SI7gBe/"

echo -e "${GREEN}Opening panel at:${NC} ${PANEL_URL}"
echo -e "${YELLOW}Default credentials:${NC}"
echo -e "  ${BLUE}Username:${NC} admin"
echo -e "  ${BLUE}Password:${NC} admin"
echo -e "${RED}IMPORTANT: Change the default credentials immediately after login!${NC}"

# Open the panel in the default browser
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  open "${PANEL_URL}"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux
  xdg-open "${PANEL_URL}"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  # Windows
  start "${PANEL_URL}"
else
  echo -e "${YELLOW}Could not open browser automatically. Please visit:${NC}"
  echo -e "${PANEL_URL}"
fi 