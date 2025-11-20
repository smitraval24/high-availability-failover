# Cloudflare Tunnel Setup Guide

This guide explains how to set up a Cloudflare Tunnel to expose your Coffee App running on VCL2 to the internet without needing a domain or opening firewall ports.

## Architecture

```
User (Internet) → Cloudflare Edge → Cloudflare Tunnel → VCL2:3000 (Coffee App)
```

**Benefits:**
- ✅ No domain required (free `.trycloudflare.com` subdomain)
- ✅ No firewall configuration needed
- ✅ Free HTTPS/SSL included
- ✅ DDoS protection from Cloudflare
- ✅ No exposed public IP
- ✅ Auto-starts on server reboot

---

## Prerequisites

- VCL2 SSH access with sudo privileges
- Coffee app running on `http://localhost:3000`
- Cloudflare account (free - create at https://dash.cloudflare.com/sign-up)

---

## Quick Setup (Automated)

### On VCL2:

```bash
# 1. Navigate to the project
cd ~/devops-project

# 2. Make the setup script executable
chmod +x scripts/setup-cloudflare-tunnel.sh

# 3. Run the setup script
./scripts/setup-cloudflare-tunnel.sh
```

The script will:
1. ✅ Install `cloudflared`
2. ✅ Authenticate with Cloudflare (browser login required)
3. ✅ Create a persistent tunnel named `coffee-vcl2`
4. ✅ Configure the tunnel to point to `localhost:3000`
5. ✅ Install and start systemd service for auto-start
6. ✅ Display your public URL

---

## Getting Your Public URL

After setup, get your tunnel URL with:

```bash
# View current logs to see the URL
sudo journalctl -u cloudflared -n 50 | grep trycloudflare.com

# OR check tunnel info
cloudflared tunnel info coffee-vcl2
```

Your URL will look like: `https://coffee-vcl2-abc123.trycloudflare.com`

---

## Manual Setup (Step-by-Step)

If you prefer manual setup or the script fails:

### 1. Install cloudflared

```bash
# Download cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

# Make it executable and move to PATH
chmod +x cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# Verify installation
cloudflared --version
```

### 2. Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser window. If you're on a remote server:
1. Copy the URL that appears in the terminal
2. Open it in your local browser
3. Log in to Cloudflare and authorize the tunnel
4. A certificate file will be saved to `~/.cloudflared/cert.pem`

### 3. Create a Named Tunnel

```bash
cloudflared tunnel create coffee-vcl2
```

This creates a tunnel and saves credentials to `~/.cloudflared/<tunnel-id>.json`

### 4. Create Configuration File

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <your-tunnel-id>
credentials-file: /home/<username>/.cloudflared/<your-tunnel-id>.json

ingress:
  - service: http://localhost:3000
```

Replace:
- `<your-tunnel-id>` with the ID from step 3
- `<username>` with your actual username

### 5. Test the Tunnel

```bash
cloudflared tunnel run coffee-vcl2
```

Look for the line showing your public URL:
```
INF +--------------------------------------------------------------------------------------------+
INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable): |
INF |  https://coffee-vcl2-abc123.trycloudflare.com                                             |
INF +--------------------------------------------------------------------------------------------+
```

Press `Ctrl+C` to stop the test.

### 6. Install as System Service

```bash
# Install the service
sudo cloudflared service install

# Enable auto-start on boot
sudo systemctl enable cloudflared

# Start the service
sudo systemctl start cloudflared

# Check status
sudo systemctl status cloudflared
```

---

## Managing the Tunnel

### Service Commands

```bash
# Check status
sudo systemctl status cloudflared

# Start tunnel
sudo systemctl start cloudflared

# Stop tunnel
sudo systemctl stop cloudflared

# Restart tunnel
sudo systemctl restart cloudflared

# View logs (real-time)
sudo journalctl -u cloudflared -f

# View last 50 log lines
sudo journalctl -u cloudflared -n 50
```

### Tunnel Commands

```bash
# List all tunnels
cloudflared tunnel list

# Get tunnel info
cloudflared tunnel info coffee-vcl2

# Delete tunnel (careful!)
cloudflared tunnel delete coffee-vcl2
```

---

## Testing Your Setup

Once the tunnel is running:

```bash
# Get your public URL from logs
PUBLIC_URL=$(sudo journalctl -u cloudflared -n 100 | grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1)

echo "Your public URL: $PUBLIC_URL"

# Test from VCL2
curl $PUBLIC_URL/coffees

# Or test from your local machine
curl https://your-tunnel-url.trycloudflare.com/coffees
```

Expected response:
```json
[
  {"id":1,"name":"Espresso","price":"2.50"},
  {"id":2,"name":"Latte","price":"3.50"},
  {"id":3,"name":"Cappuccino","price":"3.00"}
]
```

---

## Troubleshooting

### Tunnel Not Starting

```bash
# Check service status
sudo systemctl status cloudflared

# View detailed logs
sudo journalctl -u cloudflared -n 100

# Check if coffee app is running
curl http://localhost:3000/coffees

# Restart tunnel
sudo systemctl restart cloudflared
```

### Can't Get Public URL

```bash
# Method 1: Check logs
sudo journalctl -u cloudflared | grep trycloudflare.com

# Method 2: Check tunnel info
cloudflared tunnel info coffee-vcl2

# Method 3: Check service logs
sudo journalctl -u cloudflared -n 200 --no-pager
```

### Authentication Issues

```bash
# Re-authenticate
cloudflared tunnel login

# Check certificate
ls -la ~/.cloudflared/cert.pem

# Verify tunnel credentials
ls -la ~/.cloudflared/*.json
```

### Coffee App Not Accessible

```bash
# Ensure app is running
cd ~/devops-project/coffee_project
docker-compose ps

# Check if app responds locally
curl http://localhost:3000/coffees

# Restart app if needed
docker-compose restart
```

---

## Security Considerations

✅ **Advantages:**
- No public IP exposure (VCL2 IP remains hidden)
- Automatic HTTPS/SSL encryption
- DDoS protection from Cloudflare
- No firewall port opening required
- Free Cloudflare security features

⚠️ **Notes:**
- The `.trycloudflare.com` URL is public but hard to guess
- Anyone with the URL can access your app
- Consider adding authentication to your app for production use

---

## Future Enhancements

### 1. Custom Domain (Optional)

If you later buy a domain:

```bash
# Route your domain to the tunnel
cloudflared tunnel route dns coffee-vcl2 coffee.yourdomain.com
```

### 2. Load Balancing / Failover to VCL3

Add VCL3 as a backup origin:

```yaml
# ~/.cloudflared/config.yml
tunnel: <tunnel-id>
credentials-file: ~/.cloudflared/<tunnel-id>.json

ingress:
  - service: http://localhost:3000
    originRequest:
      noTLSVerify: true
      # Add health check
      httpHostHeader: localhost
```

Then set up a second tunnel on VCL3 and use Cloudflare Load Balancing (requires paid plan).

### 3. Multiple Services

Route different paths to different services:

```yaml
ingress:
  - hostname: coffee.trycloudflare.com
    path: /api/*
    service: http://localhost:3000
  - hostname: coffee.trycloudflare.com
    path: /admin/*
    service: http://localhost:8080
  - service: http_status:404
```

---

## Integration with Existing Setup

This tunnel setup works alongside your existing infrastructure:

- **VCL1**: Still handles internal routing/DNS
- **VCL2**: Coffee app accessible via both:
  - Internal: `http://152.7.178.106:3000`
  - Public: `https://your-tunnel.trycloudflare.com`
- **VCL3**: DB replication continues as normal

No changes needed to your existing setup!

---

## Useful Links

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Cloudflared GitHub](https://github.com/cloudflare/cloudflared)
- [Cloudflare Dashboard](https://dash.cloudflare.com)

---

## Quick Reference

```bash
# Setup (one-time)
./scripts/setup-cloudflare-tunnel.sh

# Get public URL
sudo journalctl -u cloudflared | grep trycloudflare.com | tail -1

# Manage service
sudo systemctl {start|stop|restart|status} cloudflared

# View logs
sudo journalctl -u cloudflared -f

# Test endpoint
curl https://your-url.trycloudflare.com/coffees
```

---

**Need Help?** Check the troubleshooting section or view logs with:
```bash
sudo journalctl -u cloudflared -n 100
```
