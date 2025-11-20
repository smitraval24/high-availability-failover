#!/bin/bash

# Cloudflare Tunnel Health Check Script
# Monitors tunnel status and coffee app availability

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Cloudflare Tunnel Health Check"
echo "======================================"
echo ""

# Check 1: Cloudflared service status
echo -n "Checking cloudflared service... "
if sudo systemctl is-active --quiet cloudflared 2>/dev/null; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo ""
    echo "Start it with: sudo systemctl start cloudflared"
    exit 1
fi

# Check 2: Coffee app status
echo -n "Checking coffee app... "
if curl -s http://localhost:3000/coffees > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Responding${NC}"
else
    echo -e "${RED}✗ Not responding${NC}"
    echo ""
    echo "Check app status with: cd ~/devops-project/coffee_project && docker-compose ps"
    exit 1
fi

# Check 3: Get tunnel URL
echo -n "Fetching tunnel URL... "
TUNNEL_URL=$(sudo journalctl -u cloudflared -n 200 --no-pager 2>/dev/null | grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)

if [ -n "$TUNNEL_URL" ]; then
    echo -e "${GREEN}✓ Found${NC}"
    echo ""
    echo "Public URL: $TUNNEL_URL"
else
    echo -e "${YELLOW}! URL not found in logs${NC}"
    echo ""
    echo "Check logs: sudo journalctl -u cloudflared -f"
    exit 1
fi

# Check 4: Test public access
echo -n "Testing public access... "
if curl -s "$TUNNEL_URL/coffees" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Accessible${NC}"
else
    echo -e "${RED}✗ Not accessible${NC}"
    echo ""
    echo "The tunnel may be starting up. Wait a few seconds and try again."
    exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}All checks passed!${NC}"
echo "======================================"
echo ""
echo "Your coffee app is publicly accessible at:"
echo "  $TUNNEL_URL"
echo ""
echo "Test endpoints:"
echo "  curl $TUNNEL_URL/coffees"
echo "  curl $TUNNEL_URL/orders"
echo ""
