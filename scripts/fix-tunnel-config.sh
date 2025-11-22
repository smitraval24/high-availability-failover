#!/usr/bin/env bash
# fix-tunnel-config.sh - Fix Cloudflare tunnel configuration

echo "Checking Cloudflare tunnel configuration..."
echo ""

# Find the config file
if [ -f "$HOME/.cloudflared/config.yml" ]; then
    CONFIG_FILE="$HOME/.cloudflared/config.yml"
elif [ -f "/etc/cloudflared/config.yml" ]; then
    CONFIG_FILE="/etc/cloudflared/config.yml"
else
    echo "ERROR: Cannot find cloudflared config file"
    exit 1
fi

echo "Config file: $CONFIG_FILE"
echo ""
echo "Current configuration:"
cat "$CONFIG_FILE"
echo ""

# Check if the config needs updating
if grep -q "noTLSVerify" "$CONFIG_FILE" 2>/dev/null; then
    echo "✓ Configuration already has noTLSVerify setting"
else
    echo "Adding noTLSVerify setting to fix SSL issues..."

    # Backup original config
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    # Create updated config
    cat > /tmp/cloudflared-config-new.yml << 'EOF'
tunnel: YOUR_TUNNEL_ID
credentials-file: /home/vpatel29/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: devopsproject.dpdns.org
    service: http://localhost:3000
    originRequest:
      noTLSVerify: true
      http2Origin: false
  - service: http_status:404
EOF

    echo ""
    echo "New configuration created at /tmp/cloudflared-config-new.yml"
    echo "Please manually update your tunnel configuration in Cloudflare dashboard"
    echo "Or apply this config and restart the tunnel"
fi

echo ""
echo "To restart tunnel after changes:"
echo "  sudo systemctl restart cloudflared"
echo "  sudo journalctl -u cloudflared -f"
