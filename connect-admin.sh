#!/bin/bash

# Script to connect to the 3x-ui admin panel
echo "Connecting to 3x-ui admin panel..."

# Admin panel credentials (from environment or defaults)
XUI_USERNAME=${XUI_USERNAME:-admin}
XUI_PASSWORD=${XUI_PASSWORD:-admin}
PANEL_PATH=${PANEL_PATH:-BXv8SI7gBe}
VPN_DOMAIN=${VPN_DOMAIN:-service.foodshare.club}

# Force HTTP for admin panel access
ADMIN_URL="http://${VPN_DOMAIN}:2053/${PANEL_PATH}/"

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