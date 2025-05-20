#!/bin/bash

# Script to connect to the 3x-ui admin panel via Caddy reverse proxy
echo "Connecting to 3x-ui admin panel through Caddy reverse proxy..."

# Admin panel credentials (from environment or defaults)
XUI_USERNAME=${XUI_USERNAME:-admin}
XUI_PASSWORD=${XUI_PASSWORD:-admin}
PANEL_PATH=${PANEL_PATH:-BXv8SI7gBe}
VPN_DOMAIN=${VPN_DOMAIN:-service.foodshare.club}

# Use HTTPS through Caddy reverse proxy - no port needed
ADMIN_URL="https://${VPN_DOMAIN}/${PANEL_PATH}/"

echo "Opening admin panel at: $ADMIN_URL"
echo "Username: $XUI_USERNAME"
echo "Password: $XUI_PASSWORD"

# Detect OS and open browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open "$ADMIN_URL"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    xdg-open "$ADMIN_URL" 2>/dev/null || sensible-browser "$ADMIN_URL" 2>/dev/null || \
    echo "Please open this URL in your browser: $ADMIN_URL"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows
    start "$ADMIN_URL"
else
    echo "Unsupported OS. Please manually open this URL in your browser:"
    echo "$ADMIN_URL"
fi

# Add troubleshooting tips
echo ""
echo "🔍 Troubleshooting Tips:"
echo "1. Caddy should handle SSL certificates automatically through Cloudflare DNS"
echo "2. All traffic is now proxied through Caddy for security"
echo "3. If you have issues, check Caddy logs with: docker-compose logs caddy"
echo "4. Check 3x-ui logs with: docker-compose logs 3x-ui"