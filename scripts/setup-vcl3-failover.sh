#!/usr/bin/env bash
# setup-vcl3-failover.sh
# Sets up automatic failover monitoring on VCL3
# Run this script on VCL3

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}VCL3 Failover Setup${NC}"
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

echo "Step 1: Creating log directory..."
sudo mkdir -p /var/log/vcl-failover
sudo chown $USER:$(id -gn $USER) /var/log/vcl-failover
echo -e "${GREEN}✓ Log directory created${NC}"
echo ""

echo "Step 2: Making monitor script executable..."
chmod +x ~/devops-project/scripts/monitor-vcl2-health.sh
echo -e "${GREEN}✓ Monitor script is executable${NC}"
echo ""

echo "Step 3: Creating systemd service..."

# Create systemd service file
sudo tee /etc/systemd/system/vcl-failover-monitor.service > /dev/null << EOF
[Unit]
Description=VCL2 Health Monitor and Failover Service
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$HOME/devops-project
ExecStart=$HOME/devops-project/scripts/monitor-vcl2-health.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Resource limits
MemoryLimit=256M
CPUQuota=20%

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓ Systemd service created${NC}"
echo ""

echo "Step 4: Reloading systemd daemon..."
sudo systemctl daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"
echo ""

echo "Step 5: Enabling failover monitor service..."
sudo systemctl enable vcl-failover-monitor.service
echo -e "${GREEN}✓ Service enabled (will start on boot)${NC}"
echo ""

echo "Step 6: Starting failover monitor service..."
sudo systemctl start vcl-failover-monitor.service
echo -e "${GREEN}✓ Service started${NC}"
echo ""

# Wait for service to initialize
sleep 3

echo "Step 7: Checking service status..."
if sudo systemctl is-active --quiet vcl-failover-monitor.service; then
    echo -e "${GREEN}✓ Failover monitor is running!${NC}"
else
    echo -e "${RED}✗ Service may not be running${NC}"
    echo "Check status: sudo systemctl status vcl-failover-monitor.service"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "VCL3 Failover Monitor Configuration:"
echo "  - Monitors VCL2 at: http://152.7.178.106:3000/coffees"
echo "  - Check interval: 30 seconds"
echo "  - Failure threshold: 3 consecutive failures"
echo "  - Auto-starts VCL3 app when VCL2 fails"
echo "  - Auto-stops VCL3 app when VCL2 recovers"
echo ""
echo "Useful Commands:"
echo "  Status:  sudo systemctl status vcl-failover-monitor"
echo "  Logs:    sudo journalctl -u vcl-failover-monitor -f"
echo "  Stop:    sudo systemctl stop vcl-failover-monitor"
echo "  Start:   sudo systemctl start vcl-failover-monitor"
echo "  Restart: sudo systemctl restart vcl-failover-monitor"
echo ""
echo "Monitor Logs:"
echo "  tail -f /var/log/vcl-failover/monitor.log"
echo ""
echo "Test Failover:"
echo "  1. Stop VCL2 app: ssh vpatel29@152.7.178.106 'cd ~/devops-project/coffee_project && sudo docker-compose down'"
echo "  2. Wait ~90 seconds (3 failed checks)"
echo "  3. VCL3 will automatically start"
echo "  4. Visit: http://152.7.178.91:3000/coffees"
echo ""
