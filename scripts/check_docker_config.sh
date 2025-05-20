#!/bin/bash

# Check that docker-compose.yml exists
if [ ! -f docker-compose.yml ]; then
  echo "❌ ERROR: docker-compose.yml not found!"
  exit 1
fi

# Simple syntax check (not perfect, but better than nothing)
if docker-compose config -q >/dev/null 2>&1; then
  echo "✅ Valid docker-compose.yml syntax"
else
  echo "❌ Invalid docker-compose.yml syntax"
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
if grep -q "2053" docker-compose.yml; then
  echo "✅ Admin panel port 2053 is exposed internally"
else
  echo "❌ Admin panel port 2053 not exposed"
  exit 1
fi

# Check for admin port 54321
if grep -q "54321:54321" docker-compose.yml; then
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

# Check for environment variables related to the admin panel
if grep -q "XUI_USERNAME" docker-compose.yml && grep -q "XUI_PASSWORD" docker-compose.yml; then
  echo "✅ Admin credentials configuration found"
else
  echo "⚠️ Warning: Admin credentials not properly configured"
fi

# Check for JWT_SECRET (important for security)
if grep -q "JWT_SECRET" docker-compose.yml; then
  if grep -q "change_me_in_production" docker-compose.yml; then
    echo "⚠️ Warning: Default JWT_SECRET found. Please change it in production!"
  else
    echo "✅ JWT_SECRET is configured"
  fi
else
  echo "❌ JWT_SECRET not found - authentication may be compromised"
fi

echo "✅ All configuration checks passed"
exit 0 