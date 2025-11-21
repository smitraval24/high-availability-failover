#!/usr/bin/env bash
# setup-cloudflared-vcl3.sh
# Installs and configures cloudflared on VCL3 for failover routing
# Run this script on VCL3 (152.7.178.91)

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cloudflared Setup for VCL3 Failover${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running on VCL3
HOSTNAME=$(hostname)
if [[ ! "$HOSTNAME" =~ "178-91" ]]; then
    echo -e "${YELLOW}Warning: This script should be run on VCL3 (152.7.178.91)${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for tunnel token argument
if [ -z "${1:-}" ]; then
    echo -e "${RED}Error: Tunnel token required${NC}"
    echo ""
    echo "Usage: $0 <TUNNEL_TOKEN>"
    echo ""
    echo "Get your tunnel token from Cloudflare Zero Trust:"
    echo "  1. Go to: https://one.dash.cloudflare.com"
    echo "  2. Navigate to: Networks → Tunnels → devops_tunnel"
    echo "  3. Click 'Configure' → Copy the tunnel token"
    echo ""
    exit 1
fi

TUNNEL_TOKEN="$1"

echo "Step 1: Installing cloudflared..."
if command -v cloudflared &> /dev/null; then
    echo -e "${YELLOW}cloudflared already installed, updating...${NC}"
else
    # Download and install cloudflared
    curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i /tmp/cloudflared.deb
    rm /tmp/cloudflared.deb
fi
echo -e "${GREEN}✓ cloudflared installed${NC}"
cloudflared --version
echo ""

echo "Step 2: Installing cloudflared as a service..."
# Install cloudflared service with tunnel token
sudo cloudflared service install "$TUNNEL_TOKEN"
echo -e "${GREEN}✓ cloudflared service installed${NC}"
echo ""

echo "Step 3: Enabling cloudflared service..."
sudo systemctl enable cloudflared
echo -e "${GREEN}✓ cloudflared enabled (will start on boot)${NC}"
echo ""

echo "Step 4: Starting cloudflared service..."
sudo systemctl start cloudflared
sleep 3
echo -e "${GREEN}✓ cloudflared started${NC}"
echo ""

echo "Step 5: Verifying cloudflared status..."
if systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}✓ cloudflared is running!${NC}"
    sudo systemctl status cloudflared --no-pager | head -15
else
    echo -e "${RED}✗ cloudflared may not be running${NC}"
    echo "Check status: sudo systemctl status cloudflared"
    echo "Check logs: sudo journalctl -u cloudflared -n 50"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "VCL3 Cloudflared Configuration:"
echo "  - Tunnel: devops_tunnel (same as VCL2)"
echo "  - Service: http://localhost:3000"
echo "  - Public URL: https://devopsproject.dpdns.org"
echo ""
echo "How Failover Works:"
echo "  1. Both VCL2 and VCL3 run cloudflared connected to the same tunnel"
echo "  2. Cloudflare routes to whichever server has a healthy app on localhost:3000"
echo "  3. When VCL2 fails, failover monitor starts app on VCL3"
echo "  4. Cloudflare automatically routes traffic to VCL3"
echo "  5. When VCL2 recovers, VCL3 app stops, traffic returns to VCL2"
echo ""
echo "Useful Commands:"
echo "  Status:  sudo systemctl status cloudflared"
echo "  Logs:    sudo journalctl -u cloudflared -f"
echo "  Restart: sudo systemctl restart cloudflared"
echo ""
