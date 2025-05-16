#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test if Docker is available
echo -e "${YELLOW}Testing Docker availability...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found! Please install Docker first.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker is installed.${NC}"
    docker --version
fi

# Variables
DOCKER_COMPOSE_VERSION="v2.24.6"

# Install Docker Compose if needed
echo -e "${YELLOW}Testing Docker Compose availability...${NC}"
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing...${NC}"
    
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    
    echo "Downloading Docker Compose ${DOCKER_COMPOSE_VERSION}..."
    curl -SL https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
    
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
    
    # Create symlink for compatibility if possible
    if [ -w /usr/local/bin ]; then
        echo "Creating symlink in /usr/local/bin..."
        ln -sf $DOCKER_CONFIG/cli-plugins/docker-compose /usr/local/bin/docker-compose
    else
        echo "Cannot create symlink in /usr/local/bin (permission denied). Docker Compose will still work with 'docker compose'."
    fi
    
    echo -e "${GREEN}✅ Docker Compose installed.${NC}"
else
    echo -e "${GREEN}✅ Docker Compose is already installed.${NC}"
fi

# Verify Docker Compose works
echo -e "${YELLOW}Testing Docker Compose functionality...${NC}"
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose (plugin) works!${NC}"
    docker compose version
elif command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✅ docker-compose (standalone) works!${NC}"
    docker-compose --version
else
    echo -e "${RED}❌ Docker Compose installation failed!${NC}"
    exit 1
fi

# Validate docker-compose.yml
echo -e "${YELLOW}Validating docker-compose.yml...${NC}"
if [ ! -f docker-compose.yml ]; then
    echo -e "${RED}❌ docker-compose.yml not found!${NC}"
    exit 1
fi

# Test docker-compose.yml syntax
echo -e "${YELLOW}Testing docker-compose.yml syntax...${NC}"
if docker compose config &> /dev/null; then
    echo -e "${GREEN}✅ docker-compose.yml syntax is valid.${NC}"
else
    echo -e "${RED}❌ docker-compose.yml has syntax errors!${NC}"
    docker compose config
    exit 1
fi

# Check for required services
echo -e "${YELLOW}Checking for required services in docker-compose.yml...${NC}"
if grep -q "3x-ui:" docker-compose.yml; then
    echo -e "${GREEN}✅ 3x-ui service found.${NC}"
else
    echo -e "${RED}❌ 3x-ui service not found in docker-compose.yml!${NC}"
    exit 1
fi

# Pull the Docker image to test
echo -e "${YELLOW}Testing docker image pull (without starting)...${NC}"
docker pull ghcr.io/mhsanaei/3x-ui:latest
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Docker image pulled successfully.${NC}"
else
    echo -e "${RED}❌ Failed to pull Docker image!${NC}"
    exit 1
fi

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}All local tests passed! The workflow should run successfully.${NC}"
echo -e "${GREEN}=====================================${NC}" 