#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Try again with sudo."
  exit 1
fi

# Define domain and IP
DOMAIN="service.foodshare.club"
IP="127.0.0.1"

# Check if the entry already exists
grep -q "$IP $DOMAIN" /etc/hosts

if [ $? -ne 0 ]; then
  # Add entry if it doesn't exist
  echo "Adding $DOMAIN to /etc/hosts..."
  echo "$IP $DOMAIN" >> /etc/hosts
  echo "Done! $DOMAIN now points to $IP"
else
  echo "$DOMAIN is already configured in /etc/hosts"
fi

echo "You can now access the service at http://$DOMAIN:2053 or https://$DOMAIN:2053"

# Check that docker-compose.yml exists
if [ ! -f docker-compose.yml ]; then
  echo "❌ ERROR: docker-compose.yml not found!"
  exit 1
fi

# Validate YAML syntax
cat docker-compose.yml | python3 -c "import sys, yaml; yaml.safe_load(sys.stdin)" 2>/dev/null
if [ $? -eq 0 ]; then
  echo "✅ Valid YAML"
else
  echo "❌ Invalid YAML syntax in docker-compose.yml"
  exit 1
fi

# Check for 3x-ui service
if grep -q "3x-ui:" docker-compose.yml; then
  echo "✅ 3x-ui service found"
else
  echo "❌ 3x-ui service not found in docker-compose.yml"
  exit 1
fi

# Check for port 2053 exposure (internal)
if grep -q -- "- 2053" docker-compose.yml; then
  echo "✅ Admin panel port 2053 is exposed internally"
else
  echo "❌ Admin panel port 2053 not exposed"
  exit 1
fi

# Check for admin port 54321
if grep -q -- "54321:54321" docker-compose.yml; then
  echo "✅ Admin port 54321 is correctly mapped"
else
  echo "❌ Admin port 54321 not properly mapped"
  exit 1
fi

# Check for Caddy service (reverse proxy)
if grep -q "caddy:" docker-compose.yml; then
  echo "✅ Caddy reverse proxy service found"
else
  echo "⚠️ Warning: Caddy reverse proxy service not found"
fi

echo "✅ All configuration checks passed"
exit 0 