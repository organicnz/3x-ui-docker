#!/bin/bash

# Source utility functions and color variables
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
  source "$UTILS_PATH"
else
  echo "\033[0;31mError: utils.sh not found. Please ensure it exists in the scripts directory.\033[0m"
  exit 1
fi

echo -e "${BLUE}Setting up 3x-ui VPN for local development...${NC}"

# Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
mkdir -p db cert/nginx logs
echo -e "${GREEN}Directories created.${NC}"

# Check if the container is already running
if docker ps | grep -q "3x-ui"; then
  echo -e "${YELLOW}Container 3x-ui is already running. Stopping it...${NC}"
  docker-compose down
  echo -e "${GREEN}Container stopped.${NC}"
fi

# Start the container
echo -e "${YELLOW}Starting 3x-ui container...${NC}"
docker-compose up -d
echo -e "${GREEN}Container started.${NC}"

# Check if the container is running
if docker ps | grep -q "3x-ui"; then
  echo -e "${GREEN}Container is running successfully.${NC}"
  echo -e "${BLUE}Access the admin panel at:${NC} http://localhost:54321"
  echo -e "${BLUE}Default credentials:${NC}"
  echo -e "  Username: ${CYAN}admin${NC}"
  echo -e "  Password: ${CYAN}admin${NC}"
  echo -e "${RED}IMPORTANT: Change the default credentials immediately after login!${NC}"
else
  echo -e "${RED}Error: Container failed to start. Check logs with 'docker-compose logs'.${NC}"
  exit 1
fi

echo -e "${GREEN}Setup complete!${NC}" 