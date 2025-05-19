#!/bin/bash
# Custom entrypoint script for 3x-ui VPN Service

set -e

# Print banner
echo "=================================================="
echo "🚀 Starting 3x-ui VPN Service"
echo "=================================================="

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "📄 Loading environment variables from .env file"
  source .env
fi

# Display configuration (masking sensitive values)
echo "📋 Configuration:"
echo "Panel Path: ${PANEL_PATH}"
echo "HTTPS Port: ${HTTPS_PORT}"
echo "VPN Domain: ${VPN_DOMAIN}"
echo "Admin Email: ${ADMIN_EMAIL}"
echo "XRAY_VMESS_AEAD_FORCED: ${XRAY_VMESS_AEAD_FORCED}"
echo "JWT Secret: ********"
echo "Admin Username: ${XUI_USERNAME}"
echo "Admin Password: ********"

# Ensure required directories exist
mkdir -p db cert logs cert/service.foodshare.club

# Start services
echo "🔄 Starting Docker Compose services"
docker-compose down
docker-compose up -d

# Check container status
echo "📊 Container status:"
docker-compose ps

# Display access information
echo "🔗 Access Information:"
echo "Admin Panel: http://${VPN_DOMAIN:-localhost}:${HTTPS_PORT:-2053}/${PANEL_PATH:-BXv8SI7gBe}/"

echo "✅ Setup complete!" 