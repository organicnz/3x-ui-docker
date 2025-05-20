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