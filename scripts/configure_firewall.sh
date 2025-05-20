#!/bin/bash

# Firewall Configuration Script for 3x-ui VPN Service
# Must be run with sudo

set -e  # Exit on any error

# Color definitions for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====== Configuring Firewall for 3x-ui VPN Service ======${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Detect the firewall type
if command -v ufw &> /dev/null; then
  echo -e "${YELLOW}Detected UFW firewall${NC}"
  
  # Enable UFW if not active
  if ! ufw status | grep -q "active"; then
    echo -e "${YELLOW}Enabling UFW...${NC}"
    ufw --force enable
  fi
  
  # Configure UFW rules
  echo -e "${YELLOW}Configuring UFW rules...${NC}"
  ufw allow ssh
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw allow 2053/tcp
  ufw allow 54321/tcp
  
  # Reload UFW
  echo -e "${YELLOW}Reloading UFW...${NC}"
  ufw reload
  
  echo -e "${GREEN}UFW configured successfully${NC}"
  ufw status

elif command -v firewall-cmd &> /dev/null; then
  echo -e "${YELLOW}Detected FirewallD${NC}"
  
  # Check if FirewallD is running
  if ! systemctl is-active --quiet firewalld; then
    echo -e "${YELLOW}Starting FirewallD...${NC}"
    systemctl start firewalld
    systemctl enable firewalld
  fi
  
  # Configure FirewallD rules
  echo -e "${YELLOW}Configuring FirewallD rules...${NC}"
  firewall-cmd --zone=public --add-service=ssh --permanent
  firewall-cmd --zone=public --add-service=http --permanent
  firewall-cmd --zone=public --add-service=https --permanent
  firewall-cmd --zone=public --add-port=2053/tcp --permanent
  firewall-cmd --zone=public --add-port=54321/tcp --permanent
  
  # Reload FirewallD
  echo -e "${YELLOW}Reloading FirewallD...${NC}"
  firewall-cmd --reload
  
  echo -e "${GREEN}FirewallD configured successfully${NC}"
  firewall-cmd --list-all

elif command -v iptables &> /dev/null; then
  echo -e "${YELLOW}Using iptables directly${NC}"
  
  # Configure iptables rules
  echo -e "${YELLOW}Configuring iptables rules...${NC}"
  iptables -A INPUT -p tcp --dport 22 -j ACCEPT
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  iptables -A INPUT -p tcp --dport 2053 -j ACCEPT
  iptables -A INPUT -p tcp --dport 54321 -j ACCEPT
  
  # Save iptables rules
  if command -v iptables-save &> /dev/null; then
    echo -e "${YELLOW}Saving iptables rules...${NC}"
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules 2>/dev/null || echo -e "${RED}Could not save iptables rules${NC}"
  fi
  
  echo -e "${GREEN}iptables configured successfully${NC}"
  iptables -L
else
  echo -e "${RED}No supported firewall detected${NC}"
  echo -e "${YELLOW}Please manually configure your firewall to allow the following ports:${NC}"
  echo -e "  - SSH (22/tcp)"
  echo -e "  - HTTP (80/tcp)"
  echo -e "  - HTTPS (443/tcp)"
  echo -e "  - Admin Panel (2053/tcp)"
  echo -e "  - VPN Server (54321/tcp)"
fi

echo -e "${GREEN}====== Firewall configuration complete ======${NC}"
