# Database Replication Usage Guide

## Overview
The database replication system synchronizes the coffee database from VCL2 (primary server) to VCL3 (cold standby) every 2 minutes. This ensures VCL3 has recent data for failover scenarios.

## How It Works

### VCL2 (Primary Server)
- Runs the coffee application and PostgreSQL database actively
- Executes the replication script every 2 minutes
- Creates compressed database dumps
- Transfers dumps to VCL3 via SCP
- Triggers remote restoration on VCL3

### VCL3 (Cold Standby)
- Keeps application container stopped (cold standby)
- Automatically starts database container when replication occurs
- Restores the database from VCL2's dump
- Leaves database container running for faster subsequent replications
- Ready to take over if VCL2 fails

## Initial Setup

### 1. On VCL2 - Generate SSH Key for Replication
```bash
# Generate SSH key for secure communication with VCL3
ssh-keygen -t ed25519 -f ~/.ssh/vcl3_replication_key -N ""

# Copy public key to VCL3
ssh-copy-id -i ~/.ssh/vcl3_replication_key.pub vpatel29@152.7.178.91

# Test connection
ssh -i ~/.ssh/vcl3_replication_key vpatel29@152.7.178.91 "echo 'Connection successful'"
```

### 2. On VCL2 - Set Up SSH Config (Optional but Recommended)
```bash
cat >> ~/.ssh/config <<EOF

# VCL3 Replication
Host vcl3-replication
    HostName 152.7.178.91
    User vpatel29
    IdentityFile ~/.ssh/vcl3_replication_key
    StrictHostKeyChecking no
EOF
```

### 3. On VCL2 - Make Script Executable
```bash
cd ~/devops-project/scripts
chmod +x replicate-db.sh
```

### 4. On VCL2 - Test Manual Replication
```bash
# Run the script manually to verify it works
./replicate-db.sh
```

Expected output:
```
[2024-12-XX XX:XX:XX] Starting database replication from VCL2 to VCL3...
[2024-12-XX XX:XX:XX] Dumping database from VCL2...
[2024-12-XX XX:XX:XX] Database dump created: /tmp/coffee-replication/coffee_dev_YYYYMMDD_HHMMSS.sql.gz (XXX)
[2024-12-XX XX:XX:XX] Transferring dump to VCL3 (152.7.178.91)...
[2024-12-XX XX:XX:XX] Dump transferred successfully
[2024-12-XX XX:XX:XX] Restoring database on VCL3...
[VCL3] Starting database replication restore...
[VCL3] Starting database container...
[VCL3] Waiting for PostgreSQL to be ready...
[VCL3] PostgreSQL is ready. Restoring database...
[VCL3] Database restored successfully
[VCL3] Database contains X tables
[VCL3] Cleanup completed
[2024-12-XX XX:XX:XX] Database restored successfully on VCL3
[2024-12-XX XX:XX:XX] Replication completed successfully!
[2024-12-XX XX:XX:XX] ================================================
```

## Automated Replication (Every 2 Minutes)

### Option 1: Using Systemd Timer (Recommended)

#### Install Systemd Units
```bash
# On VCL2
cd ~/devops-project/scripts
sudo ./setup-replication.sh
```

#### Manage Replication Service
```bash
# Start timer
sudo systemctl start coffee-replication.timer

# Enable timer to start on boot
sudo systemctl enable coffee-replication.timer

# Check timer status
sudo systemctl status coffee-replication.timer

# View recent logs
sudo journalctl -u coffee-replication.service -n 50 -f

# Stop timer
sudo systemctl stop coffee-replication.timer

# Disable timer
sudo systemctl disable coffee-replication.timer
```

### Option 2: Using Cron

```bash
# On VCL2 - Edit crontab
crontab -e

# Add this line to run every 2 minutes
*/2 * * * * /home/vpatel29/devops-project/scripts/replicate-db.sh >> /var/log/coffee-replication/replicate.log 2>&1

# Create log directory if needed
sudo mkdir -p /var/log/coffee-replication
sudo chown vpatel29:vpatel29 /var/log/coffee-replication

# View logs
tail -f /var/log/coffee-replication/replicate.log
```

## Verification

### Check Database Content on VCL2
```bash
# On VCL2
sudo docker-compose -f ~/devops-project/coffee_project/docker-compose.yml exec db \
  psql -U postgres coffee_dev -c "SELECT id, name, price FROM coffees ORDER BY id;"
```

### Check Database Content on VCL3
```bash
# On VCL2 (remote check)
ssh vpatel29@152.7.178.91 "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres coffee_dev -c 'SELECT id, name, price FROM coffees ORDER BY id;'"

# Or directly on VCL3
cd ~/devops-project/coffee_project
sudo docker-compose exec db psql -U postgres coffee_dev -c "SELECT id, name, price FROM coffees ORDER BY id;"
```

### Compare Databases
Both queries should return identical results if replication is working correctly.

## Testing Replication

### Test 1: Update Data on VCL2 and Verify on VCL3

1. **Update a coffee price on VCL2:**
   ```bash
   # Via API
   curl -X PUT http://152.7.178.106:3000/coffees/1/price \
     -H "Content-Type: application/json" \
     -d '{"price": 9.99}'
   
   # Or via UI
   # Open http://152.7.178.106:3000
   # Click "Change Price" on first coffee
   # Enter 9.99 and submit
   ```

2. **Wait 2 minutes for replication**

3. **Check VCL3 database:**
   ```bash
   ssh vpatel29@152.7.178.91 "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres coffee_dev -c 'SELECT name, price FROM coffees WHERE id=1;'"
   ```
   
   Expected: Should show the updated price (9.99)

### Test 2: Replication with Stopped Containers

1. **Stop all containers on VCL3:**
   ```bash
   ssh vpatel29@152.7.178.91 "cd ~/devops-project/coffee_project && sudo docker-compose down"
   ```

2. **Update data on VCL2:**
   ```bash
   curl -X PUT http://152.7.178.106:3000/coffees/2/price \
     -H "Content-Type: application/json" \
     -d '{"price": 7.77}'
   ```

3. **Trigger manual replication:**
   ```bash
   # On VCL2
   ~/devops-project/scripts/replicate-db.sh
   ```

4. **Verify VCL3 database started and data replicated:**
   ```bash
   ssh vpatel29@152.7.178.91 "cd ~/devops-project/coffee_project && sudo docker-compose ps"
   ssh vpatel29@152.7.178.91 "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres coffee_dev -c 'SELECT name, price FROM coffees WHERE id=2;'"
   ```

## Troubleshooting

### Issue: "Permission denied" errors
**Solution:** Ensure user is in docker group or use sudo
```bash
sudo usermod -aG docker vpatel29
# Logout and login for group changes to take effect
```

### Issue: "No route to host" when connecting to VCL3
**Solution:** Check firewall rules
```bash
# On VCL3
sudo iptables -L -n | grep 22
# If needed, add rule
sudo iptables -I INPUT -s 152.7.178.0/24 -p tcp --dport 22 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### Issue: SSH asks for password
**Solution:** Ensure SSH key is properly set up
```bash
# On VCL2
ssh-copy-id -i ~/.ssh/vcl3_replication_key.pub vpatel29@152.7.178.91
```

### Issue: Database restore fails
**Solution:** Check VCL3 logs
```bash
# On VCL3
cd ~/devops-project/coffee_project
sudo docker-compose logs db
```

### Issue: Replication not running automatically
**Solution:** Check timer/cron status
```bash
# For systemd
sudo systemctl status coffee-replication.timer
sudo journalctl -u coffee-replication.service -n 20

# For cron
crontab -l
tail -f /var/log/coffee-replication/replicate.log
```

## Architecture Notes

- **VCL2**: Active primary server serving customer requests
- **VCL3**: Cold standby with synchronized data, ready for failover
- **Replication Frequency**: Every 2 minutes
- **Data Transfer**: Compressed dumps via SCP (secure)
- **Recovery Time**: ~30 seconds (time to start app container on VCL3)
- **Data Loss Window**: Maximum 2 minutes of transactions if VCL2 fails

## Failover Process (Automatic)

The VCL3 health monitor (`monitor-vcl2-health.sh`) automatically handles failover:

1. **VCL2 goes down** - Monitor detects 3 consecutive health check failures
2. **Automatic failover** - VCL3 app container starts, traffic routed via Cloudflare tunnel
3. **VCL3 serves traffic** using its replicated database (may be up to 2 min behind)

## Failback Process (When VCL2 Recovers)

When VCL2 comes back online, the system automatically handles failback with data synchronization:

### Automatic Failback (via Monitor)
The monitor script automatically triggers failback when VCL2 health checks pass:

1. **VCL2 recovers** - Monitor detects VCL2 is healthy again
2. **Database sync** - VCL3's current database is replicated TO VCL2 (reverse replication)
3. **VCL2 app starts** - Application starts with synced data
4. **Health verification** - VCL2 app health is verified
5. **Traffic reroute** - Traffic routes back to VCL2
6. **VCL3 stops** - VCL3 app stops, returns to cold standby mode

### Manual Failback
If you need to manually trigger failback:

```bash
# On VCL3
cd ~/devops-project/scripts
chmod +x failback-to-vcl2.sh reverse-replicate-db.sh
./failback-to-vcl2.sh
```

This script will:
1. Verify VCL2 connectivity and database health
2. Sync VCL3's database to VCL2 (preserves any data changes made during failover)
3. Start VCL2's application
4. Verify VCL2 app health
5. Reroute traffic to VCL2
6. Stop VCL3's app (back to cold standby)

### Manual Database Sync Only
If you only need to sync the database without full failback:

```bash
# On VCL3
cd ~/devops-project/scripts
chmod +x reverse-replicate-db.sh
./reverse-replicate-db.sh
```

## Data Persistence on Deployment

The migration script (`migrate.js`) is designed to preserve existing data:

- **Tables are created** if they don't exist (using `CREATE TABLE IF NOT EXISTS`)
- **Seed data is only inserted** if the coffees table is empty
- **Existing data is never overwritten** during deployment

This ensures:
- Pushing new code won't reset your database
- VCL2 keeps its data after deployment
- VCL3 keeps its replicated data after code sync

## Monitoring

### Check Replication Logs
```bash
# Systemd
sudo journalctl -u coffee-replication.service -f

# Cron
tail -f /var/log/coffee-replication/replicate.log
```

### Check Last Replication Time
```bash
# On VCL2
ls -lth /tmp/coffee-replication/

# On VCL3
ssh vpatel29@152.7.178.91 "sudo docker-compose -f ~/devops-project/coffee_project/docker-compose.yml exec -T db psql -U postgres coffee_dev -c \"SELECT NOW() - pg_last_xact_replay_timestamp() AS replication_lag;\""
```

## Maintenance

### Clean Up Old Dumps
The script automatically cleans dumps older than 1 hour. To manually clean:
```bash
# On VCL2
rm -f /tmp/coffee-replication/coffee_dev_*.sql.gz

# On VCL3
ssh vpatel29@152.7.178.91 "rm -f /tmp/coffee_dev_*.sql.gz"
```

### Stop Replication Temporarily
```bash
# Systemd
sudo systemctl stop coffee-replication.timer

# Cron
crontab -e
# Comment out the replication line with #
```

### Resume Replication
```bash
# Systemd
sudo systemctl start coffee-replication.timer

# Cron
crontab -e
# Uncomment the replication line
```
