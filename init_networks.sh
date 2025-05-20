#!/bin/bash

# Script to initialize external networks and volumes for Caddy + 3x-ui setup
echo "Initializing external Docker networks and volumes..."

# Create external networks
echo "Creating Docker networks..."
docker network create web || echo "Network 'web' already exists"
docker network create no-zero-trust-cloudflared || echo "Network 'no-zero-trust-cloudflared' already exists"
docker network create zero-trust-cloudflared || echo "Network 'zero-trust-cloudflared' already exists"

# Create external volumes
echo "Creating Docker volumes..."
docker volume create caddy_data || echo "Volume 'caddy_data' already exists"
docker volume create caddy || echo "Volume 'caddy' already exists"
docker volume create tls || echo "Volume 'tls' already exists"
docker volume create vault-data || echo "Volume 'vault-data' already exists"

echo "Initialization complete! You can now run: docker-compose up -d" 