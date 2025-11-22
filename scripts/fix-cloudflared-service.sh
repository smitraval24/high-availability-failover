#!/usr/bin/env bash
# fix-cloudflared-service.sh
# Fix cloudflared systemd service to use config file instead of token
# This enables the keepalive and timeout settings in cloudflared-config.yml

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Fixing cloudflared service to use config file...${NC}"
echo ""

# Backup current service file
if [ -f /etc/systemd/system/cloudflared.service ]; then
    echo "Backing up current service file..."
    sudo cp /etc/systemd/system/cloudflared.service /etc/systemd/system/cloudflared.service.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create new service file that uses config.yml
echo "Creating new service file..."
sudo tee /etc/systemd/system/cloudflared.service > /dev/null << 'EOF'
[Unit]
Description=cloudflared
After=network.target

[Service]
Type=simple
User=vpatel29
ExecStart=/usr/bin/cloudflared tunnel --config /home/vpatel29/.cloudflared/config.yml run
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓ Service file updated${NC}"

# Ensure config file exists
if [ ! -f ~/.cloudflared/config.yml ]; then
    echo -e "${RED}ERROR: Config file not found at ~/.cloudflared/config.yml${NC}"
    echo "Please ensure the config file exists before restarting the service."
    exit 1
fi

echo -e "${GREEN}✓ Config file found${NC}"

# Reload systemd
echo "Reloading systemd..."
sudo systemctl daemon-reload

# Restart cloudflared
echo "Restarting cloudflared..."
sudo systemctl restart cloudflared

sleep 3

# Check status
echo ""
echo "Checking service status..."
if sudo systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}✓ Cloudflared is running with new configuration!${NC}"
    echo ""
    sudo systemctl status cloudflared --no-pager -l | head -20
else
    echo -e "${RED}✗ Cloudflared failed to start${NC}"
    echo "Check logs: sudo journalctl -u cloudflared -n 50"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Fix Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Cloudflared is now using the config file with keepalive settings."
echo "This should fix the intermittent 502 errors."
echo ""
