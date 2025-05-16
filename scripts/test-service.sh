#!/bin/bash

# 3x-ui VPN service testing script
# This script tests various components of the 3x-ui VPN service

set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
  local level=$1
  local message=$2
  local color=$NC
  
  case $level in
    "INFO") color=$BLUE ;;
    "SUCCESS") color=$GREEN ;;
    "WARNING") color=$YELLOW ;;
    "ERROR") color=$RED ;;
  esac
  
  echo -e "${color}[$level] $message${NC}"
}

# Check if Docker and Docker Compose are installed
check_dependencies() {
  log "INFO" "Checking dependencies..."
  
  if ! command -v docker &> /dev/null; then
    log "ERROR" "Docker is not installed. Please install Docker first."
    exit 1
  else
    log "SUCCESS" "Docker is installed: $(docker --version)"
  fi
  
  if ! command -v docker-compose &> /dev/null; then
    log "ERROR" "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
  else
    log "SUCCESS" "Docker Compose is installed: $(docker-compose --version)"
  fi
}

# Test Docker Compose configuration
test_docker_compose() {
  log "INFO" "Testing Docker Compose configuration..."
  
  if [ ! -f docker-compose.yml ]; then
    log "ERROR" "docker-compose.yml not found in the current directory."
    exit 1
  fi
  
  # Validate YAML syntax
  if ! docker-compose config > /dev/null; then
    log "ERROR" "Docker Compose configuration is invalid."
    exit 1
  else
    log "SUCCESS" "Docker Compose configuration is valid."
  fi
  
  # Check for required services
  if ! grep -q "3x-ui:" docker-compose.yml; then
    log "ERROR" "3x-ui service not found in docker-compose.yml."
    exit 1
  else
    log "SUCCESS" "3x-ui service found in configuration."
  fi
  
  # Check for required ports
  if ! grep -q "443:443" docker-compose.yml; then
    log "WARNING" "HTTPS port (443) might not be configured correctly."
  else
    log "SUCCESS" "HTTPS port (443) is configured."
  fi
  
  if ! grep -q "2053:2053" docker-compose.yml; then
    log "WARNING" "VPN panel port (2053) might not be configured correctly."
  else
    log "SUCCESS" "VPN panel port (2053) is configured."
  fi
}

# Test Docker image
test_docker_image() {
  log "INFO" "Testing Docker image..."
  
  log "INFO" "Pulling Docker image: ghcr.io/mhsanaei/3x-ui:latest"
  if ! docker pull ghcr.io/mhsanaei/3x-ui:latest; then
    log "ERROR" "Failed to pull Docker image."
    exit 1
  else
    log "SUCCESS" "Docker image pulled successfully."
  fi
  
  # Check image size
  image_size=$(docker images ghcr.io/mhsanaei/3x-ui:latest --format "{{.Size}}")
  log "INFO" "Image size: $image_size"
  
  # Check exposed ports
  exposed_ports=$(docker inspect ghcr.io/mhsanaei/3x-ui:latest --format '{{json .Config.ExposedPorts}}')
  log "INFO" "Exposed ports: $exposed_ports"
}

# Test container startup
test_container_startup() {
  log "INFO" "Testing container startup..."
  
  # Create test directories
  mkdir -p ./test_logs ./test_cert
  touch test_db.db
  chmod 644 test_db.db
  
  # Start the container in test mode
  log "INFO" "Starting container in test mode..."
  
  # Create test docker-compose file
  cat > docker-compose.test.yml << EOL
version: '3.8'
services:
  3x-ui:
    image: ghcr.io/mhsanaei/3x-ui:latest
    container_name: 3x-ui-test
    restart: "no"
    ports:
      - 54321:54321
    volumes:
      - ./test_db.db:/etc/x-ui/x-ui.db
      - ./test_cert:/root/cert
      - ./test_logs:/var/log/x-ui
    environment:
      - XRAY_VMESS_AEAD_FORCED=false
      - PANEL_PATH=test
EOL
  
  # Start the container
  if ! docker-compose -f docker-compose.test.yml up -d; then
    log "ERROR" "Failed to start test container."
    rm -f docker-compose.test.yml
    exit 1
  fi
  
  # Wait for container to start
  log "INFO" "Waiting for container to initialize..."
  sleep 20
  
  # Check if container is running
  container_status=$(docker ps --filter "name=3x-ui-test" --format "{{.Status}}")
  if [ -z "$container_status" ]; then
    log "ERROR" "Container failed to start."
    docker-compose -f docker-compose.test.yml logs
    docker-compose -f docker-compose.test.yml down
    rm -f docker-compose.test.yml
    exit 1
  else
    log "SUCCESS" "Container is running: $container_status"
  fi
  
  # Test service availability
  log "INFO" "Testing service endpoints..."
  http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:54321/login)
  if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 302 ]; then
    log "SUCCESS" "Admin panel is accessible (HTTP $http_code)."
  else
    log "ERROR" "Admin panel returned HTTP $http_code."
    docker-compose -f docker-compose.test.yml logs
  fi
  
  # Cleanup
  log "INFO" "Cleaning up test environment..."
  docker-compose -f docker-compose.test.yml down
  rm -f docker-compose.test.yml
  rm -rf ./test_logs ./test_cert test_db.db
}

# Security tests
test_security() {
  log "INFO" "Running security tests..."
  
  # Check for unsafe configurations in docker-compose.yml
  if grep -q "privileged: true" docker-compose.yml; then
    log "ERROR" "Security issue: Container runs with privileged mode."
  else
    log "SUCCESS" "Container does not use privileged mode."
  fi
  
  if grep -q "network_mode: host" docker-compose.yml; then
    log "WARNING" "Container uses host network mode, which could expose more ports than intended."
  else
    log "SUCCESS" "Container does not use host network mode."
  fi
  
  # Check for sensitive volume mounts
  if grep -q "/etc:" docker-compose.yml; then
    log "WARNING" "Container mounts /etc directory, which could be a security risk."
  else
    log "SUCCESS" "No sensitive /etc mount found."
  fi
  
  if grep -q "/var:" docker-compose.yml; then
    log "WARNING" "Container mounts /var directory, which could be a security risk."
  else
    log "SUCCESS" "No sensitive /var mount found."
  fi
}

# Run all tests
run_all_tests() {
  check_dependencies
  test_docker_compose
  test_docker_image
  test_security
  test_container_startup
  
  log "SUCCESS" "All tests completed successfully!"
}

# Main script execution
log "INFO" "Starting 3x-ui VPN service tests..."
run_all_tests 