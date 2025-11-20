# Automatic Rollback Feature for VCL2

## Overview

The deployment pipeline now includes **automatic rollback** functionality. If a deployment fails health checks, the system automatically restores the previous working version with zero manual intervention required.

## How It Works

### Deployment Flow with Rollback

```
1. Backup Phase
   └─ Create backup of current running container → coffee_app:backup

2. Deployment Phase
   ├─ Pull latest code from main branch
   ├─ Stop old containers
   ├─ Build new containers
   └─ Start new containers

3. Health Check Phase (60 seconds)
   ├─ HTTP endpoint check: GET /coffees
   ├─ Database connectivity check
   └─ Container status check

4. Decision Phase
   ├─ Health Checks PASS ✓
   │  ├─ Remove backup image
   │  ├─ Sync code to VCL3
   │  └─ Deployment complete!
   │
   └─ Health Checks FAIL ✗
      ├─ Stop failed containers
      ├─ Restore backup image
      ├─ Start restored containers
      ├─ Verify rollback succeeded
      └─ Deployment failed (app still running with old version)
```

## Scripts

### 1. `backup-container.sh`
**Location:** `scripts/backup-container.sh`

**Purpose:** Creates a backup of the currently running container before deployment

**Usage:**
```bash
cd ~/devops-project
./scripts/backup-container.sh
```

**What it does:**
- Commits the running `coffee_app` container to `coffee_app:backup` image
- Saves backup metadata (timestamp, container ID)
- Removes any previous backup before creating new one

### 2. `rollback-container.sh`
**Location:** `scripts/rollback-container.sh`

**Purpose:** Automatically restores the backup when health checks fail

**Usage:**
```bash
cd ~/devops-project
./scripts/rollback-container.sh
```

**What it does:**
- Stops failed containers
- Tags backup image as latest
- Restarts containers with backup version
- Verifies rollback succeeded (health check)
- Exits with error if rollback fails

### 3. `cleanup-backup.sh`
**Location:** `scripts/cleanup-backup.sh`

**Purpose:** Removes backup after successful deployment

**Usage:**
```bash
cd ~/devops-project
./scripts/cleanup-backup.sh
```

**What it does:**
- Removes `coffee_app:backup` image
- Cleans up backup metadata files
- Frees up disk space

## Health Check Criteria

Deployment is considered **successful** if all of the following pass within 60 seconds:

1. **HTTP Check:** `curl http://152.7.178.106:3000/` returns 200 OK
2. **Database Check:** PostgreSQL responds to `pg_isready`
3. **Container Status:** All containers are running

If **any** check fails, automatic rollback is triggered.

## Manual Rollback

If you need to manually rollback (e.g., you noticed an issue after deployment):

```bash
# SSH into VCL2
ssh vpatel29@152.7.178.106

# Navigate to project
cd ~/devops-project

# Run rollback script
./scripts/rollback-container.sh
```

**Note:** Manual rollback only works if the backup image still exists. The backup is automatically cleaned up after the next successful deployment.

## Database Handling

**Important:** The rollback mechanism **only affects the application container**, not the database.

- ✅ Application code is rolled back
- ❌ Database changes are NOT rolled back
- ✅ Database remains running and unchanged

This design choice ensures:
- Data integrity is preserved
- No data loss during rollback
- Faster rollback times

If you need to rollback database changes, use the VCL3 replication backup manually.

## Monitoring Rollback

### Via GitHub Actions

When a rollback occurs, you'll see in the workflow logs:

```
=== HEALTH CHECKS FAILED - INITIATING ROLLBACK ===
[timestamp] Starting rollback process...
[timestamp] Stopping failed containers...
[timestamp] Restoring backup image as latest...
[timestamp] Starting containers with backed-up version...
[timestamp] ✓ Rollback successful! Application is responding.
=== ROLLBACK COMPLETED ===
```

### Via SSH on VCL2

Check deployment logs:
```bash
# View recent Docker container logs
sudo docker-compose -f ~/devops-project/coffee_project/docker-compose.yml logs --tail=100

# Check if backup exists
docker images | grep backup

# View backup metadata
cat /tmp/coffee_deployment/backup.timestamp
```

## Troubleshooting

### Rollback Failed

If the rollback itself fails:

1. **Check if backup exists:**
   ```bash
   docker images | grep coffee_app
   # Should see: coffee_app:backup
   ```

2. **Manually restore backup:**
   ```bash
   cd ~/devops-project/coffee_project
   sudo docker-compose down
   docker tag coffee_app:backup coffee_app:latest
   sudo docker-compose up -d
   ```

3. **Check application logs:**
   ```bash
   sudo docker logs coffee_app
   ```

### No Backup Available

If no backup image exists:

1. **Check VCL3 (cold standby):**
   ```bash
   ssh vpatel29@152.7.178.91
   cd ~/devops-project/coffee_project
   sudo docker-compose up -d
   ```

2. **Update DNS on VCL1 to point to VCL3**

3. **Fix issue on VCL2 and redeploy**

### Backup Taking Too Much Space

Backups are automatically cleaned up after successful deployments. To manually clean:

```bash
cd ~/devops-project
./scripts/cleanup-backup.sh
```

## Testing Rollback

To test the rollback mechanism:

1. **Intentionally break the app:**
   ```bash
   # On a test branch, introduce a bug that fails health checks
   # Example: Make the /coffees endpoint return 500
   ```

2. **Create PR and merge to main**

3. **Watch GitHub Actions:**
   - Deployment will attempt
   - Health checks will fail
   - Rollback will automatically trigger
   - Old version will be restored

4. **Verify app still works:**
   ```bash
   curl http://152.7.178.106:3000/coffees
   # Should return coffee list (old working version)
   ```

## Best Practices

1. **Always test in dev branch first** before merging to main
2. **Monitor GitHub Actions** during deployment
3. **Keep backups** - don't manually delete `coffee_app:backup` during deployments
4. **Check VCL3 replication** - ensure VCL3 has recent database backups
5. **Document breaking changes** - note if a deployment requires manual intervention

## Limitations

- Only one backup is kept (the immediately previous version)
- Database changes are not rolled back
- Rollback requires backup image to exist
- Manual changes on VCL2 may be lost if not committed

## Emergency Contacts

If rollback fails and app is down:

1. Check VCL3 (cold standby): `152.7.178.91`
2. Manually restore from Git: `git checkout <previous-commit>`
3. Check database replication logs: `/var/log/coffee-replication/`

