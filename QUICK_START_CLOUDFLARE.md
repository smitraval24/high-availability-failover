# Cloudflare Tunnel - Quick Start Guide for VCL2

## 🚀 Setup Steps (Run on VCL2)

### Step 1: SSH into VCL2
```bash
ssh <your-username>@152.7.178.106
```

### Step 2: Navigate to Project
```bash
cd ~/devops-project
```

### Step 3: Ensure Coffee App is Running
```bash
cd coffee_project
docker-compose ps

# If not running, start it:
docker-compose up -d

# Test it locally:
curl http://localhost:3000/coffees
```

### Step 4: Run Cloudflare Tunnel Setup
```bash
cd ~/devops-project
chmod +x scripts/setup-cloudflare-tunnel.sh
./scripts/setup-cloudflare-tunnel.sh
```

**What will happen:**
1. Script installs `cloudflared`
2. Opens browser for Cloudflare login (you'll need to authenticate)
3. Creates a tunnel named `coffee-vcl2`
4. Installs systemd service for auto-start
5. Shows your public URL

**Important:** During authentication, if you're SSH'd into VCL2:
- The script will display a URL
- Copy that URL
- Open it in your LOCAL browser
- Log in to Cloudflare
- Complete authorization

### Step 5: Get Your Public URL
```bash
chmod +x scripts/get-tunnel-url.sh
./scripts/get-tunnel-url.sh
```

Or manually:
```bash
sudo journalctl -u cloudflared | grep trycloudflare.com | tail -1
```

Your URL will look like:
```
https://coffee-vcl2-abc123xyz.trycloudflare.com
```

### Step 6: Test Public Access
```bash
# Replace with your actual URL
curl https://your-tunnel-url.trycloudflare.com/coffees

# Expected response:
# [{"id":1,"name":"Espresso","price":"2.50"},...]
```

### Step 7: Verify Auto-Start
```bash
# Check service status
sudo systemctl status cloudflared

# Should show: active (running)
```

---

## ✅ Verification Checklist

Run the health check script:
```bash
chmod +x scripts/check-tunnel-health.sh
./scripts/check-tunnel-health.sh
```

This checks:
- ✓ Cloudflared service running
- ✓ Coffee app responding
- ✓ Tunnel URL found
- ✓ Public access working

---

## 📊 Useful Commands

### Get Tunnel Status
```bash
sudo systemctl status cloudflared
```

### View Live Logs
```bash
sudo journalctl -u cloudflared -f
```

### Restart Tunnel
```bash
sudo systemctl restart cloudflared
```

### List All Tunnels
```bash
cloudflared tunnel list
```

### Get Tunnel Info
```bash
cloudflared tunnel info coffee-vcl2
```

---

## 🧪 Testing Your Public URL

Once you have your URL, test all endpoints:

```bash
# Save your URL for easy testing
export TUNNEL_URL="https://your-tunnel-url.trycloudflare.com"

# Test 1: Get coffees
curl $TUNNEL_URL/coffees

# Test 2: Place an order
curl -X POST $TUNNEL_URL/order \
  -H "Content-Type: application/json" \
  -d '{"coffeeId": 1, "quantity": 2}'

# Test 3: View all orders
curl $TUNNEL_URL/orders

# Test 4: From your browser
echo "Open in browser: $TUNNEL_URL"
```

---

## 🔧 Troubleshooting

### Problem: "cloudflared: command not found"
```bash
# Check installation
which cloudflared

# If not found, reinstall:
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
```

### Problem: "Service not running"
```bash
# Check status
sudo systemctl status cloudflared

# View logs for errors
sudo journalctl -u cloudflared -n 50

# Restart service
sudo systemctl restart cloudflared
```

### Problem: "Can't find public URL"
```bash
# Wait a few seconds, then check logs
sudo journalctl -u cloudflared -n 100 | grep trycloudflare.com

# Or view live logs
sudo journalctl -u cloudflared -f
```

### Problem: "502 Bad Gateway"
```bash
# Coffee app might not be running
cd ~/devops-project/coffee_project
docker-compose ps
docker-compose logs app

# Restart app if needed
docker-compose restart app
```

### Problem: Authentication Failed
```bash
# Re-authenticate
cloudflared tunnel login

# Make sure you complete the browser login
# Check for cert.pem
ls -la ~/.cloudflared/cert.pem
```

---

## 📝 What You'll Share

After setup, you can share your public URL with anyone:

**Your Coffee App URL:**
```
https://coffee-vcl2-[random].trycloudflare.com
```

**Share these test commands:**
```bash
# View menu
curl https://your-url.trycloudflare.com/coffees

# Place order
curl -X POST https://your-url.trycloudflare.com/order \
  -H "Content-Type: application/json" \
  -d '{"coffeeId": 1, "quantity": 2}'
```

**Or just share the URL for browser access:**
```
https://your-url.trycloudflare.com
```

---

## 🎯 Next Steps After Setup

1. **Save your public URL** somewhere safe
2. **Update project documentation** with the URL
3. **Test failover scenario** (future work)
4. **Set up monitoring** (optional)

---

## 🔐 Security Notes

- ✅ VCL2 IP address is hidden from public
- ✅ HTTPS encryption automatic
- ✅ DDoS protection from Cloudflare
- ✅ No firewall changes needed
- ⚠️ URL is public but hard to guess
- ⚠️ Consider adding authentication for production

---

## 📚 Full Documentation

For detailed information, see:
- [CLOUDFLARE_TUNNEL_SETUP.md](../CLOUDFLARE_TUNNEL_SETUP.md)
- [Main README.md](../README.md)

---

## ⏱️ Estimated Time

- Initial setup: 5-10 minutes
- Testing: 2-3 minutes
- **Total: ~15 minutes**

---

**Need help?** Check the full documentation or view logs:
```bash
sudo journalctl -u cloudflared -n 100
```
