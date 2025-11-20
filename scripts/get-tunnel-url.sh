#!/bin/bash

# Quick command to get the Cloudflare Tunnel public URL
# Usage: ./scripts/get-tunnel-url.sh

echo "Fetching Cloudflare Tunnel URL..."
echo ""

# Method 1: From systemd logs
URL=$(sudo journalctl -u cloudflared -n 200 --no-pager 2>/dev/null | grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)

if [ -n "$URL" ]; then
    echo "✓ Tunnel URL found:"
    echo ""
    echo "  $URL"
    echo ""
    echo "Test it with:"
    echo "  curl $URL/coffees"
    echo ""
    exit 0
fi

# Method 2: Check if cloudflared is running
if ! systemctl is-active --quiet cloudflared 2>/dev/null; then
    echo "✗ Cloudflared service is not running."
    echo ""
    echo "Start it with:"
    echo "  sudo systemctl start cloudflared"
    echo ""
    exit 1
fi

# Method 3: If service just started, wait a bit
echo "Service is running, but URL not found in logs yet."
echo "The tunnel may be starting up..."
echo ""
echo "Try again in a few seconds, or view live logs:"
echo "  sudo journalctl -u cloudflared -f"
echo ""

exit 1
