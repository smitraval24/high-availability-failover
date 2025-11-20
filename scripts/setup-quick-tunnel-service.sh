#!/bin/bash

# Setup Cloudflare Quick Tunnel as a Systemd Service
# This makes the tunnel auto-start on boot

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "======================================"
echo "Setup Cloudflare Quick Tunnel Service"
echo "======================================"
echo ""

# Get current username
CURRENT_USER=$(whoami)

echo -e "${YELLOW}Creating systemd service file...${NC}"

# Create service file
sudo tee /etc/systemd/system/cloudflared-quick-tunnel.service > /dev/null << EOF
[Unit]
Description=Cloudflare Quick Tunnel for Coffee App
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:3000
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓ Service file created${NC}"
echo ""

echo -e "${YELLOW}Enabling and starting service...${NC}"

# Reload systemd
sudo systemctl daemon-reload

# Enable service (auto-start on boot)
sudo systemctl enable cloudflared-quick-tunnel.service

# Start service
sudo systemctl start cloudflared-quick-tunnel.service

echo -e "${GREEN}✓ Service started${NC}"
echo ""

# Wait for tunnel to initialize
echo -e "${YELLOW}Waiting for tunnel to initialize (10 seconds)...${NC}"
sleep 10

# Check status
if sudo systemctl is-active --quiet cloudflared-quick-tunnel; then
    echo -e "${GREEN}✓ Tunnel service is running!${NC}"
else
    echo -e "${RED}✗ Service may not be running${NC}"
    echo "Check status: sudo systemctl status cloudflared-quick-tunnel"
    exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}Setup Complete!${NC}"
echo "======================================"
echo ""
echo "Get your public URL:"
echo "  sudo journalctl -u cloudflared-quick-tunnel -n 50 | grep 'https://'"
echo ""
echo "Useful commands:"
echo "  Status:  sudo systemctl status cloudflared-quick-tunnel"
echo "  Logs:    sudo journalctl -u cloudflared-quick-tunnel -f"
echo "  Restart: sudo systemctl restart cloudflared-quick-tunnel"
echo "  Stop:    sudo systemctl stop cloudflared-quick-tunnel"
echo ""
echo "Note: The URL will change each time the service restarts."
echo "      This is normal for quick tunnels without a domain."
echo ""
