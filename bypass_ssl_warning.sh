#!/bin/bash

# Script to open Chrome with SSL certificate warnings disabled
# For testing purposes only - not recommended for regular browsing!

echo "⚠️  WARNING: This script opens Chrome with security features disabled."
echo "Only use this for testing your 3x-ui VPN admin panel locally."
echo ""
echo "Launching Chrome with SSL warnings disabled..."

# Detect OS and set appropriate Chrome command
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open -a "Google Chrome" --args --ignore-certificate-errors --user-data-dir=/tmp/chrome_dev_profile http://service.foodshare.club:2053/BXv8SI7gBe/
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    google-chrome --ignore-certificate-errors --user-data-dir=/tmp/chrome_dev_profile http://service.foodshare.club:2053/BXv8SI7gBe/
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows with Git Bash
    start chrome --ignore-certificate-errors --user-data-dir=C:\\temp\\chrome_dev_profile http://service.foodshare.club:2053/BXv8SI7gBe/
else
    echo "Unsupported OS. Please manually open Chrome with these arguments:"
    echo "--ignore-certificate-errors --user-data-dir=/tmp/chrome_dev_profile"
    echo "And navigate to: http://service.foodshare.club:2053/BXv8SI7gBe/"
fi

echo ""
echo "Chrome should now open with certificate warnings disabled."
echo "Access the admin panel at: http://service.foodshare.club:2053/BXv8SI7gBe/"
echo "Default credentials: admin/admin (or as set in your environment variables)" 