#!/usr/bin/env bash
# setup-cloudflared-vcl3.sh
# Setup Cloudflare Tunnel on VCL3 for high availability
# This allows VCL3 to serve traffic through the same domain when VCL2 is down

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Cloudflare Tunnel Setup for VCL3${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running on VCL3
HOSTNAME=$(hostname)
if [[ ! "$HOSTNAME" =~ vcl.*91 ]]; then
    echo -e "${YELLOW}Warning: This script should be run on VCL3 (152.7.178.91)${NC}"
    echo "Current hostname: $HOSTNAME"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${YELLOW}Step 1: Installing cloudflared${NC}"

# Check if cloudflared is already installed
if command -v cloudflared &> /dev/null; then
    echo -e "${GREEN}✓ cloudflared is already installed${NC}"
    cloudflared --version
else
    echo "Installing cloudflared..."

    # Download and install cloudflared
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb

    echo -e "${GREEN}✓ cloudflared installed${NC}"
fi

echo ""
echo -e "${YELLOW}Step 2: Setting up tunnel configuration${NC}"

# Create .cloudflared directory if it doesn't exist
mkdir -p ~/.cloudflared

# Check if configuration already exists from repository
if [ -f "$HOME/devops-project/config/cloudflared-config.yml" ]; then
    echo "Copying config from repository..."
    cp "$HOME/devops-project/config/cloudflared-config.yml" ~/.cloudflared/config.yml
    echo -e "${GREEN}✓ Configuration file copied from repository${NC}"
fi

# Copy tunnel credentials from VCL2
if [ ! -f ~/.cloudflared/f40f7dcb-3dc4-4be2-b1cf-28d678721bc1.json ]; then
    echo -e "${YELLOW}Tunnel credentials not found. Attempting to copy from VCL2...${NC}"

    # Try to copy from VCL2
    if scp -o StrictHostKeyChecking=no vpatel29@152.7.178.106:~/.cloudflared/f40f7dcb-3dc4-4be2-b1cf-28d678721bc1.json ~/.cloudflared/ 2>/dev/null; then
        echo -e "${GREEN}✓ Credentials copied from VCL2${NC}"
    else
        echo -e "${RED}ERROR: Could not copy credentials from VCL2${NC}"
        echo ""
        echo "Please manually copy the credentials:"
        echo "  scp vpatel29@152.7.178.106:~/.cloudflared/f40f7dcb-3dc4-4be2-b1cf-28d678721bc1.json ~/.cloudflared/"
        echo ""
        echo "After copying, run this script again."
        exit 1
    fi
fi

echo -e "${GREEN}✓ Tunnel credentials found${NC}"

echo ""
echo -e "${YELLOW}Step 3: Setting up systemd service${NC}"

# Create systemd service file
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

echo -e "${GREEN}✓ Systemd service file created${NC}"

# Reload systemd
sudo systemctl daemon-reload

# Enable and start the service
echo "Enabling cloudflared service..."
sudo systemctl enable cloudflared

echo "Starting cloudflared service..."
sudo systemctl start cloudflared

sleep 3

echo ""
echo -e "${YELLOW}Step 4: Verifying setup${NC}"
if sudo systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}✓ cloudflared is running!${NC}"
    sudo systemctl status cloudflared --no-pager | head -15
else
    echo -e "${RED}✗ cloudflared may not be running${NC}"
    echo "Check status: sudo systemctl status cloudflared"
    echo "Check logs: sudo journalctl -u cloudflared -n 50"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "VCL3 is now running the Cloudflare tunnel!"
echo ""
echo "How High Availability Works:"
echo "  1. Both VCL2 and VCL3 run cloudflared connected to the same tunnel"
echo "  2. Cloudflare automatically load-balances between healthy servers"
echo "  3. When VCL2 goes down, traffic automatically goes to VCL3"
echo "  4. When VCL2 recovers, traffic is distributed between both"
echo "  5. Failover scripts stop VCL3 app when returning to normal state"
echo ""
echo "Service commands:"
echo "  Start:   sudo systemctl start cloudflared"
echo "  Stop:    sudo systemctl stop cloudflared"
echo "  Status:  sudo systemctl status cloudflared"
echo "  Logs:    sudo journalctl -u cloudflared -f"
echo ""
