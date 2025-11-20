# Rollback Test Plan - Breaking Change

## What Was Changed

**File:** `coffee_project/app.js`

**Change:** Added middleware that returns HTTP 503 (Service Unavailable) for the root endpoint `/`

```javascript
// Lines 11-22 in app.js
app.use((req, res, next) => {
  if (req.path === '/' || req.path === '/index.html') {
    console.error('SIMULATED FAILURE: Returning 503 to trigger rollback');
    return res.status(503).json({ 
      error: 'Service temporarily unavailable', 
      message: 'This is a simulated failure to test automatic rollback'
    });
  }
  next();
});
```

## Why This Breaks Health Check But Passes Tests

### ✅ Tests Will PASS
- Unit tests only check specific API endpoints:
  - `/coffees` ✓
  - `/order` ✓
  - `/orders` ✓
  - `/coffees/:id/price` ✓
- Tests never check the root `/` endpoint
- ESLint will pass (no syntax errors)

### ❌ Health Check Will FAIL
- Health check does: `curl -sS -f http://152.7.178.106:3000/`
- This hits the root `/` endpoint
- The `-f` flag makes curl fail on HTTP errors (4xx, 5xx)
- Returns HTTP 503 → Health check fails
- **Triggers automatic rollback!**

## Expected Workflow

```
1. Commit and push to dev branch ✓
   └─ "test: Add breaking change to test automatic rollback"

2. Create PR: dev → main ✓

3. GitHub Actions: PR Tests
   ├─ Linting: PASS ✓ (no syntax errors)
   └─ Unit Tests: PASS ✓ (tests don't check root endpoint)

4. Merge PR to main ✓

5. GitHub Actions: Deploy to VCL2
   ├─ Backup current container ✓
   ├─ Pull latest code ✓
   ├─ Build new container ✓
   ├─ Start new container ✓
   └─ Health Check: FAIL ✗
      └─ curl http://VCL2:3000/ returns 503

6. Automatic Rollback Triggered! 🔄
   ├─ Stop failed container
   ├─ Restore backup image
   ├─ Start restored container
   └─ Verify rollback succeeded

7. GitHub Actions Result: ❌ Deployment Failed
   └─ But VCL2 is still running with OLD working version!

8. Verify App Still Works
   └─ curl http://152.7.178.106:3000/coffees
      └─ Returns coffee list (old version) ✓
```

## What You'll See in GitHub Actions Logs

### When Health Check Fails:
```
Running health checks against VCL2 from Actions runner
Waiting for services to be ready...
== App HTTP check ==
HTTP not ready (1/12)
HTTP not ready (2/12)
HTTP not ready (3/12)
...
HTTP not ready (12/12)
✗ App health check failed
```

### When Rollback Triggers:
```
=== HEALTH CHECKS FAILED - INITIATING ROLLBACK ===
[timestamp] Backup image found. Starting rollback process...
[timestamp] Stopping failed containers...
[timestamp] Restoring backup image as latest...
[timestamp] Starting containers with backed-up version...
[timestamp] Waiting for application to be ready...
[timestamp] ✓ Rollback successful! Application is responding.
[timestamp] ✓ Application is serving data correctly
=== ROLLBACK COMPLETED SUCCESSFULLY ===
The application has been restored to the previous working version.
```

## Timeline Estimate

- PR Tests: ~3-5 minutes
- Deployment: ~2 minutes
- Health Check: ~1 minute (will fail after trying for 60 seconds)
- Rollback: ~30 seconds
- **Total: ~6-8 minutes**

## Verifying the Rollback

After the workflow completes (with failure status):

```bash
# 1. Check app is still running (with OLD version)
curl http://152.7.178.106:3000/coffees
# Expected: Returns coffee list (old working version)

# 2. Try the root endpoint (NEW broken version was rolled back)
curl -v http://152.7.178.106:3000/
# Expected: Returns 200 OK with index.html (old version)
# NOT 503! (the broken version was rolled back)

# 3. SSH to VCL2 and check containers
ssh vpatel29@152.7.178.106
docker ps
# Expected: coffee_app container is running

# 4. Check Docker images
docker images | grep coffee_app
# Expected: coffee_app:latest (restored from backup)
# May or may not see coffee_app:backup (might be cleaned up)
```

## After Testing - Revert the Breaking Change

Once you've verified the rollback works, revert this breaking change:

```bash
# On dev branch
git revert HEAD
git push origin dev

# Create new PR to merge the revert
# This will deploy successfully and restore normal functionality
```

Or manually remove the breaking middleware from `app.js`:
```javascript
// Remove lines 11-22 in app.js
// (the middleware that returns 503)
```

## Key Points

✅ This is a **safe test** - app will automatically rollback
✅ No data loss - database is not affected
✅ Tests pass - CI/CD validation works
✅ Health check fails - triggers rollback mechanism
✅ VCL2 stays online - rolled back to working version

🎯 **Goal:** Prove automatic rollback works when health checks fail!

