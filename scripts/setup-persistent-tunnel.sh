#!/bin/bash

# Setup Persistent Cloudflare Tunnel with Stable URL
# This creates a named tunnel that persists across restarts

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "======================================"
echo "Setup Persistent Cloudflare Tunnel"
echo "======================================"
echo ""

TUNNEL_NAME="coffee-vcl2-persistent"
CLOUDFLARED_DIR="$HOME/.cloudflared"
CURRENT_USER=$(whoami)

# Check if already authenticated
if [ ! -f "$CLOUDFLARED_DIR/cert.pem" ]; then
    echo -e "${RED}Error: Not authenticated. Run 'cloudflared tunnel login' first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking for existing tunnel...${NC}"

# Delete old tunnel if exists
if cloudflared tunnel list 2>/dev/null | grep -q "$TUNNEL_NAME"; then
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    echo "Found existing tunnel, deleting..."
    cloudflared tunnel delete -f "$TUNNEL_ID" 2>/dev/null || true
fi

echo -e "${GREEN}✓ Ready to create new tunnel${NC}"
echo ""

echo -e "${YELLOW}Step 2: Creating persistent tunnel...${NC}"
cloudflared tunnel create "$TUNNEL_NAME"
TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
echo -e "${GREEN}✓ Tunnel created: $TUNNEL_ID${NC}"
echo ""

echo -e "${YELLOW}Step 3: Creating tunnel configuration...${NC}"

# Create config with ingress rules
cat > "$CLOUDFLARED_DIR/config.yml" << EOF
tunnel: $TUNNEL_ID
credentials-file: $CLOUDFLARED_DIR/$TUNNEL_ID.json

ingress:
  - service: http://localhost:3000
EOF

echo -e "${GREEN}✓ Configuration created${NC}"
echo ""

echo -e "${YELLOW}Step 4: Generating public hostname...${NC}"
echo ""
echo "Your tunnel is ready. To get a public URL, you have two options:"
echo ""
echo "Option A: Use Cloudflare Dashboard (Recommended for stable URL)"
echo "  1. Go to https://one.dash.cloudflare.com/"
echo "  2. Navigate to 'Networks' > 'Tunnels'"
echo "  3. Find tunnel: $TUNNEL_NAME"
echo "  4. Add a 'Public Hostname'"
echo "  5. Set hostname: coffee-vcl2 (or any name)"
echo "  6. This gives you: https://coffee-vcl2-<team>.cloudflare.com"
echo ""
echo "Option B: Use this command to get tunnel subdomain:"
echo "  cloudflared tunnel route dns $TUNNEL_NAME coffee-vcl2"
echo "  (Requires a Cloudflare account with Zero Trust)"
echo ""
read -p "Press Enter after setting up public hostname in dashboard, or press Ctrl+C to do it later..."

echo ""
echo -e "${YELLOW}Step 5: Creating systemd service...${NC}"

# Create systemd service
sudo tee /etc/systemd/system/cloudflared-persistent.service > /dev/null << SVCEOF
[Unit]
Description=Cloudflare Persistent Tunnel - Coffee App
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
ExecStart=/usr/local/bin/cloudflared --config $CLOUDFLARED_DIR/config.yml tunnel run $TUNNEL_NAME
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

echo -e "${GREEN}✓ Service file created${NC}"
echo ""

echo -e "${YELLOW}Step 6: Enabling and starting service...${NC}"

sudo systemctl daemon-reload
sudo systemctl enable cloudflared-persistent.service
sudo systemctl start cloudflared-persistent.service

sleep 5

if sudo systemctl is-active --quiet cloudflared-persistent; then
    echo -e "${GREEN}✓ Tunnel service is running!${NC}"
else
    echo -e "${RED}✗ Service may not be running${NC}"
    exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}Setup Complete!${NC}"
echo "======================================"
echo ""
echo "Tunnel Details:"
echo "  Name: $TUNNEL_NAME"
echo "  ID:   $TUNNEL_ID"
echo ""
echo "Next Steps:"
echo "  1. Go to: https://one.dash.cloudflare.com/"
echo "  2. Navigate to: Networks > Tunnels"
echo "  3. Click on: $TUNNEL_NAME"
echo "  4. Add 'Public Hostname' to get your stable URL"
echo ""
echo "Useful commands:"
echo "  Status:  sudo systemctl status cloudflared-persistent"
echo "  Logs:    sudo journalctl -u cloudflared-persistent -f"
echo "  Restart: sudo systemctl restart cloudflared-persistent"
echo ""
