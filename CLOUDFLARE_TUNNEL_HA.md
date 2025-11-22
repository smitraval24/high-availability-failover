# Cloudflare Tunnel High Availability Setup

This document explains how the Cloudflare Tunnel is configured for high availability across VCL2 and VCL3.

## Overview

Both VCL2 (primary) and VCL3 (standby) run the same Cloudflare Tunnel, providing automatic failover for the public domain `https://devopsproject.dpdns.org`.

## Architecture

```
Internet
   ↓
Cloudflare (cloudflare.com)
   ↓
Cloudflare Tunnel (devops_tunnel)
   ├─→ VCL2 (152.7.178.106) - Primary
   └─→ VCL3 (152.7.178.91)  - Standby
```

- **Tunnel ID**: `f40f7dcb-3dc4-4be2-b1cf-28d678721bc1`
- **Domain**: `devopsproject.dpdns.org`
- **Backend Service**: `http://localhost:3000`

## How It Works

### Normal Operation (VCL2 Active)
1. Both VCL2 and VCL3 run `cloudflared` service
2. Both connect to the same tunnel
3. VCL2 has the app running on port 3000
4. VCL3 app is stopped (cold standby)
5. Cloudflare routes all traffic to VCL2 (only healthy backend)

### During Failover (VCL2 Down)
1. VCL2 goes down (app or server fails)
2. VCL3 health monitor detects failure (3 failed checks)
3. VCL3 automatically starts the app container
4. Cloudflare detects VCL2 backend is unhealthy
5. **Cloudflare automatically routes traffic to VCL3**
6. Users experience zero downtime (tunnel stayed up)

### During Failback (VCL2 Recovers)
1. VCL2 comes back online
2. VCL3 monitor detects VCL2 is healthy
3. VCL3 syncs its database to VCL2
4. VCL2 app starts with synced data
5. VCL3 app stops (returns to standby)
6. Cloudflare routes traffic back to VCL2

## Initial Setup

### VCL2 Setup (Already Done)
Cloudflared is already installed and running on VCL2.

### VCL3 Setup (One-Time)

**Step 1: SSH into VCL3**
```bash
ssh vpatel29@152.7.178.91
```

**Step 2: Run the setup script**
```bash
cd ~/devops-project/scripts
./setup-cloudflared-vcl3.sh
```

This script will:
- Install cloudflared
- Copy tunnel credentials from VCL2
- Copy tunnel config from repository
- Create systemd service
- Start and enable cloudflared

**Step 3: Verify**
```bash
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -n 20
```

You should see: "Registered tunnel connection" messages

## Configuration Files

### Tunnel Config (`config/cloudflared-config.yml`)
```yaml
tunnel: f40f7dcb-3dc4-4be2-b1cf-28d678721bc1
credentials-file: /home/vpatel29/.cloudflared/f40f7dcb-3dc4-4be2-b1cf-28d678721bc1.json

ingress:
  - hostname: devopsproject.dpdns.org
    service: http://localhost:3000
    originRequest:
      noTLSVerify: true
  - service: http_status:404
```

### Systemd Service (`/etc/systemd/system/cloudflared.service`)
```ini
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
```

## Automatic Updates

The CI/CD pipeline automatically updates the tunnel configuration on both servers:

**On VCL2:**
- Deploys new config from repository
- Restarts cloudflared service

**On VCL3:**
- Syncs code from main branch
- Updates tunnel config
- Restarts cloudflared service (if installed)

## Monitoring

### Check Tunnel Status on VCL2
```bash
ssh vpatel29@152.7.178.106
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -f
```

### Check Tunnel Status on VCL3
```bash
ssh vpatel29@152.7.178.91
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -f
```

### Check Cloudflare Dashboard
1. Go to: https://one.dash.cloudflare.com
2. Navigate to: Networks → Tunnels
3. Click on your tunnel
4. You should see **2 connectors** (VCL2 and VCL3)

## Troubleshooting

### Domain not accessible
```bash
# Check if cloudflared is running on both servers
ssh vpatel29@152.7.178.106 "sudo systemctl status cloudflared"
ssh vpatel29@152.7.178.91 "sudo systemctl status cloudflared"

# Check if app is running
curl http://152.7.178.106:3000/health
curl http://152.7.178.91:3000/health  # Should fail if in standby
```

### Tunnel won't start on VCL3
```bash
# Check credentials file exists
ls -la ~/.cloudflared/f40f7dcb-3dc4-4be2-b1cf-28d678721bc1.json

# Check config file exists
ls -la ~/.cloudflared/config.yml

# View detailed logs
sudo journalctl -u cloudflared -n 100 --no-pager

# Restart the service
sudo systemctl restart cloudflared
```

### Manual Commands

**Restart cloudflared on VCL2:**
```bash
ssh vpatel29@152.7.178.106 "sudo systemctl restart cloudflared"
```

**Restart cloudflared on VCL3:**
```bash
ssh vpatel29@152.7.178.91 "sudo systemctl restart cloudflared"
```

**Test failover manually:**
```bash
# Stop VCL2 app
ssh vpatel29@152.7.178.106 "cd ~/devops-project/coffee_project && sudo docker-compose stop app"

# Start VCL3 app
ssh vpatel29@152.7.178.91 "cd ~/devops-project/coffee_project && sudo docker-compose up -d"

# Wait 10 seconds for Cloudflare to detect the change
sleep 10

# Test domain
curl https://devopsproject.dpdns.org/coffees
```

## Benefits

✅ **Zero downtime during failover** - Tunnel stays up on VCL3
✅ **Automatic traffic routing** - Cloudflare handles failover
✅ **No manual intervention** - Everything is automated
✅ **Always accessible** - Domain works even if VCL2 is down
✅ **Load balancing** - Cloudflare can distribute traffic if both are up

## Security Notes

- Tunnel credentials (`*.json` file) are NOT stored in git
- Credentials must be manually copied from VCL2 to VCL3 once
- Config file (`config.yml`) is stored in git and auto-deployed
- Both servers must have the same credentials to use the same tunnel

## Related Scripts

- [`scripts/setup-cloudflared-vcl3.sh`](scripts/setup-cloudflared-vcl3.sh) - Initial setup on VCL3
- [`scripts/monitor-vcl2-health.sh`](scripts/monitor-vcl2-health.sh) - Health monitoring (starts/stops app)
- [`config/cloudflared-config.yml`](config/cloudflared-config.yml) - Tunnel configuration
- [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) - CI/CD pipeline

## Testing

See [MANUAL_TESTING_STEPS.md](MANUAL_TESTING_STEPS.md) for comprehensive testing procedures including failover testing.
