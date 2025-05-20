#!/bin/bash

echo -e "\033[1;33mSetting proper permissions...\033[0m"

# Create required directories first
mkdir -p db cert logs cert/***

# Find all directories/files except .git, caddy_data/logs, and other potentially problematic paths
# Use -print0 and xargs -0 to handle spaces in filenames
find . -type d -not -path "./.git/*" -not -path "./caddy_data/logs*" -not -path "./caddy_data/caddy/*" -not -path "./.history/*" -print0 | xargs -0 -I{} chmod 755 "{}"
find . -type f -not -path "./.git/*" -not -path "./caddy_data/logs*" -not -path "./caddy_data/caddy/*" -not -path "./.history/*" -print0 | xargs -0 -I{} chmod 644 "{}"

# Make scripts executable
find ./scripts -type f -name "*.sh" -print0 | xargs -0 -I{} chmod +x "{}" 2>/dev/null || true
chmod +x *.sh 2>/dev/null || true

echo -e "\033[0;32mPermissions set successfully!\033[0m" 