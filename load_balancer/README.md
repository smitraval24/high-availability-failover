# Load Balancer Configuration

## Overview

This directory contains the Nginx load balancer configuration used on VCL1 (Router server) to distribute traffic between VCL2 (primary) and VCL3 (standby).

## File

**`nginx-load-balancer.conf`**
- **Deployed on**: VCL1 (152.7.178.184)
- **Location**: `/etc/nginx/sites-available/coffee-lb`
- **Enabled at**: `/etc/nginx/sites-enabled/coffee-lb`

## How It Works

### Backend Servers

```nginx
upstream coffee_backend {
    server 152.7.178.106:3000 max_fails=3 fail_timeout=10s;  # VCL2 (Primary)
    server 152.7.178.91:3000 backup max_fails=3 fail_timeout=10s;  # VCL3 (Standby)
}
```

- **VCL2 (152.7.178.106:3000)**: Primary server
  - Handles all traffic by default
  - Marked as failed after 3 consecutive failures
  - 10-second failure timeout

- **VCL3 (152.7.178.91:3000)**: Standby server (marked as `backup`)
  - Only receives traffic when VCL2 is down
  - Automatically activated on VCL2 failure
  - Automatically deactivated when VCL2 recovers

### Traffic Routing

1. **Normal Operation**: All requests → VCL2
2. **VCL2 Failure**: Nginx detects VCL2 is down → Routes to VCL3
3. **VCL2 Recovery**: Nginx detects VCL2 is back → Routes back to VCL2

### Endpoints

- **Port 80**: HTTP traffic
- **Port 3000**: Direct application access
- **`/health`**: Health check endpoint (returns "healthy")

## Deployment

### On VCL1 (Router)

```bash
# Copy configuration
sudo cp nginx-load-balancer.conf /etc/nginx/sites-available/coffee-lb

# Enable the site
sudo ln -s /etc/nginx/sites-available/coffee-lb /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

## Testing

### Test Load Balancer

```bash
# From any machine
curl http://152.7.178.184/coffees
```

### Test Health Check

```bash
curl http://152.7.178.184/health
# Should return: healthy
```

### Test Failover

```bash
# 1. Stop VCL2
ssh vpatel29@152.7.178.106
cd ~/devops-project/coffee_project
sudo docker-compose down

# 2. Traffic should automatically route to VCL3
curl http://152.7.178.184/coffees  # Now served by VCL3

# 3. Restart VCL2
sudo docker-compose up -d

# 4. Traffic automatically routes back to VCL2
curl http://152.7.178.184/coffees  # Now served by VCL2
```

## Features

✅ **Automatic Failover**: Switches to standby when primary fails
✅ **Automatic Recovery**: Switches back when primary recovers
✅ **Health Monitoring**: Continuous backend health checks
✅ **Zero-Downtime**: Seamless traffic switching
✅ **Load Distribution**: Can be extended to round-robin

## Configuration Details

| Setting | Value | Description |
|---------|-------|-------------|
| `max_fails` | 3 | Failures before marking server down |
| `fail_timeout` | 10s | Time before retrying failed server |
| `proxy_connect_timeout` | 5s | Connection timeout |
| `proxy_send_timeout` | 10s | Send timeout |
| `proxy_read_timeout` | 10s | Read timeout |

## Logs

**Access logs**: `/var/log/nginx/access.log`
**Error logs**: `/var/log/nginx/error.log`

```bash
# View access logs
sudo tail -f /var/log/nginx/access.log

# View error logs
sudo tail -f /var/log/nginx/error.log
```

## Architecture

```
         Users
           │
           ▼
    ┌──────────────┐
    │  VCL1        │
    │  Nginx LB    │
    │  Port 80     │
    └──────┬───────┘
           │
    ┌──────┴──────┐
    │             │
    ▼             ▼
┌────────┐    ┌────────┐
│ VCL2   │    │ VCL3   │
│Primary │    │Standby │
│:3000   │    │:3000   │
└────────┘    └────────┘
  Active       Backup
```

## Troubleshooting

### Nginx won't start

```bash
# Check configuration syntax
sudo nginx -t

# Check if port 80 is already in use
sudo netstat -tlnp | grep :80
```

### Backend not reachable

```bash
# Test VCL2 directly
curl http://152.7.178.106:3000/coffees

# Test VCL3 directly
curl http://152.7.178.91:3000/coffees
```

### Traffic not failing over

```bash
# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Verify backend servers in config
sudo nginx -T | grep upstream -A 5
```
