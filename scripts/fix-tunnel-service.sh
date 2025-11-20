#!/bin/bash

# Fix Cloudflare Tunnel Systemd Service Installation
# Run this after the main setup script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "======================================"
echo "Fixing Cloudflare Tunnel Service"
echo "======================================"
echo ""

TUNNEL_NAME="coffee-vcl2"
CLOUDFLARED_DIR="$HOME/.cloudflared"
CONFIG_FILE="$CLOUDFLARED_DIR/config.yml"

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Installing systemd service with config path...${NC}"

# Uninstall existing service if any (ignore errors)
sudo cloudflared service uninstall 2>/dev/null || true

# Install with explicit config path
sudo cloudflared --config "$CONFIG_FILE" service install

echo -e "${GREEN}✓ Service installed${NC}"
echo ""

echo -e "${YELLOW}Step 2: Enabling and starting service...${NC}"

sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

echo -e "${GREEN}✓ Service enabled and started${NC}"
echo ""

echo -e "${YELLOW}Step 3: Checking service status...${NC}"
sleep 3

if sudo systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}✓ Service is running!${NC}"
else
    echo -e "${RED}Warning: Service may not be running${NC}"
    echo "Check status with: sudo systemctl status cloudflared"
fi

echo ""
echo "======================================"
echo -e "${GREEN}Service Installation Complete!${NC}"
echo "======================================"
echo ""
echo "Get your tunnel URL with:"
echo "  sudo journalctl -u cloudflared -n 50 | grep 'https://'"
echo ""
echo "Or wait a few seconds and run:"
echo "  ./scripts/get-tunnel-url.sh"
echo ""
