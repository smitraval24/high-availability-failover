# Failover Database Fix - Status Report

## Problem Statement
When VCL2 failed and VCL3 activated during failover, VCL3 was serving **seed data** instead of the replicated production data from VCL2.

## Root Cause Analysis
1. The monitor script started containers with `docker compose up -d --build`
2. This triggered database migrations and seeds instead of restoring from backup
3. The replication script was storing backups on VCL3 but the failover didn't use them

## Changes Made

### 1. Fixed Monitor Script (`ansible/setup-vcl3-monitor.yml`)

**Before:**
```bash
activate_vcl3() {
    sudo docker compose up -d --build  # Started with migrations/seeds
}
```

**After:**
```bash
activate_vcl3() {
    # 1. Start database container first
    sudo docker compose up -d db
    
    # 2. Wait for DB to be ready
    docker exec coffee_db pg_isready -U postgres
    
    # 3. Find and restore latest backup
    LATEST_BACKUP=$(ls -t /tmp/db-backup/coffee_db_*.sql | head -1)
    cat $LATEST_BACKUP | docker exec -i coffee_db psql -U postgres -d coffee_dev
    
    # 4. Then start app container
    sudo docker compose up -d app
}
```

### 2. Added Reverse Replication for Failback

When VCL2 comes back online, the monitor now:
1. **Syncs VCL3 database back to VCL2** (preserves data created during failover)
2. Then deactivates VCL3

```bash
deactivate_vcl3() {
    # Sync database BACK to VCL2 before stopping
    sync_database_to_vcl2()
    
    # Then stop VCL3
    docker compose down
}
```

### 3. Fixed Replication Script (`ansible/setup-replication.yml`)

**Before:** Tried to restore to VCL3's running database (which doesn't exist in standby)

**After:** Just stores backup on VCL3 for failover use:
- Creates `/tmp/db-backup/coffee_db_YYYYMMDD_HHMMSS.sql` on VCL3
- Keeps last 5 backups
- Monitor script finds and restores latest during failover

## Failover Flow (Updated)

```
Normal Operation (VCL2 Active):
┌─────────────────────────────────────────────────────────────┐
│  VCL2 (Primary)         VCL3 (Cold Standby)                 │
│  ├── App running        ├── Containers stopped              │
│  ├── DB running         ├── Backup files stored             │
│  └── Serving traffic    └── Monitor watching VCL2           │
│                                                             │
│  Every 30 min: VCL2 ────backup────> VCL3:/tmp/db-backup/   │
└─────────────────────────────────────────────────────────────┘

Failover (VCL2 Down):
┌─────────────────────────────────────────────────────────────┐
│  1. Monitor detects VCL2 is down (3 failed checks)          │
│  2. Start DB container on VCL3                              │
│  3. Restore latest backup: coffee_db_*.sql                  │
│  4. Start App container on VCL3                             │
│  5. VCL3 now serving with PRODUCTION DATA                   │
└─────────────────────────────────────────────────────────────┘

Failback (VCL2 Returns):
┌─────────────────────────────────────────────────────────────┐
│  1. Monitor detects VCL2 is healthy again                   │
│  2. Sync VCL3 database BACK to VCL2 (preserve new data)     │
│  3. Stop VCL3 containers                                    │
│  4. VCL2 now primary again with all data                    │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Instructions

After updating the Ansible files, redeploy:

```bash
# On your local machine
cd ansible

# Redeploy replication setup (updates sync script on VCL2)
ansible-playbook -i inventory.yml setup-replication.yml

# Redeploy monitor (updates failover script on VCL3)
ansible-playbook -i inventory.yml setup-vcl3-monitor.yml
```

## Testing the Fix

1. **Ensure backup exists on VCL3:**
   ```bash
   # On VCL3
   ls -la /tmp/db-backup/
   ```

2. **Manually trigger replication (on VCL2):**
   ```bash
   /home/sraval/scripts/sync-db-to-vcl3.sh
   ```

3. **Test failover:**
   ```bash
   # On VCL2 - stop the app
   cd ~/devops-project/coffee_project
   sudo docker compose down
   ```

4. **Verify VCL3 has correct data:**
   ```bash
   # On VCL3 - check if orders/data matches VCL2
   curl http://localhost:3000/coffees
   ```

5. **Test failback:**
   ```bash
   # On VCL2 - restart the app
   sudo docker compose up -d
   ```

## Key Files Changed

| File | Purpose |
|------|---------|
| `ansible/setup-vcl3-monitor.yml` | Monitor script with DB restore on failover |
| `ansible/setup-replication.yml` | Replication script (just stores backup) |

## What This Fixes

| Before | After |
|--------|-------|
| VCL3 starts with seed data | VCL3 restores from latest backup |
| Data created during failover is lost | Data synced back to VCL2 on failback |
| Replication tries to restore to stopped DB | Backup stored for failover use |
