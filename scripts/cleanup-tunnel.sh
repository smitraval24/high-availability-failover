#!/bin/bash

# Clean up existing Cloudflare Tunnel setup
# Run this before re-running setup if you have issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Cloudflare Tunnel Cleanup"
echo "======================================"
echo ""

TUNNEL_NAME="coffee-vcl2"
CLOUDFLARED_DIR="$HOME/.cloudflared"

echo -e "${YELLOW}This will clean up your existing tunnel setup.${NC}"
echo -e "${YELLOW}You'll need to re-run the setup script after this.${NC}"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""

# Step 1: Stop and remove systemd service
echo -e "${YELLOW}Step 1: Stopping and removing systemd service...${NC}"
if sudo systemctl is-active --quiet cloudflared 2>/dev/null; then
    sudo systemctl stop cloudflared
    echo "  ✓ Service stopped"
fi

if sudo systemctl is-enabled --quiet cloudflared 2>/dev/null; then
    sudo systemctl disable cloudflared
    echo "  ✓ Service disabled"
fi

sudo cloudflared service uninstall 2>/dev/null || echo "  ✓ Service not installed or already removed"
echo ""

# Step 2: Delete tunnel
echo -e "${YELLOW}Step 2: Deleting tunnel '$TUNNEL_NAME'...${NC}"
if cloudflared tunnel list 2>/dev/null | grep -q "$TUNNEL_NAME"; then
    # Get tunnel ID and delete by ID
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    if [ -n "$TUNNEL_ID" ]; then
        cloudflared tunnel delete -f "$TUNNEL_ID" 2>/dev/null || cloudflared tunnel delete "$TUNNEL_ID" 2>/dev/null || echo "  ! Could not delete tunnel, may need manual cleanup"
        echo "  ✓ Tunnel deleted (ID: $TUNNEL_ID)"
    else
        echo "  ! Could not find tunnel ID"
    fi
else
    echo "  ✓ Tunnel does not exist or already deleted"
fi
echo ""

# Step 3: Clean up configuration directory
echo -e "${YELLOW}Step 3: Cleaning up configuration files...${NC}"
if [ -d "$CLOUDFLARED_DIR" ]; then
    # Keep cert.pem (authentication), remove everything else
    if [ -f "$CLOUDFLARED_DIR/cert.pem" ]; then
        echo "  ✓ Keeping authentication certificate"
    fi
    
    # Remove config.yml and tunnel credentials
    rm -f "$CLOUDFLARED_DIR/config.yml"
    rm -f "$CLOUDFLARED_DIR"/*.json
    
    echo "  ✓ Configuration files cleaned"
else
    echo "  ✓ Configuration directory does not exist"
fi
echo ""

echo "======================================"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Re-run the setup script:"
echo "     ./scripts/setup-cloudflare-tunnel.sh"
echo ""
echo "Note: Your authentication (cert.pem) has been preserved."
echo "      You won't need to log in again."
echo ""
