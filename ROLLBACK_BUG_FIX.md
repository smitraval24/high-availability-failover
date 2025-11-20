# Critical Rollback Bug Fix

## The Bug You Discovered 🐛

**Problem:** Rollback restored a container, but it was still running the broken version!

**Root Cause:** When rollback ran `docker-compose up -d`, it **rebuilt the app from source** (which had the broken code from git pull), instead of using the backup image.

## Why This Happened

### docker-compose.yml Configuration:
```yaml
app:
  build:          # ← This tells docker-compose to build from source
    context: .
    dockerfile: Dockerfile
```

### Rollback Flow (Broken):
```
1. Git pull → Gets broken code in working directory
2. Deployment fails
3. Rollback tags backup: coffee_app:backup → coffee_app:latest
4. Rollback runs: docker-compose up -d
5. Docker-compose sees "build:" → Rebuilds from current directory
6. Current directory has broken code! ❌
7. Container runs with broken code (not backup)
```

## The Fix

### Changed Files:

**1. `scripts/rollback-container.sh`:**
- Changed: `docker-compose up -d` → `docker-compose up -d --no-build`
- This prevents rebuilding and uses the existing backup image

**2. All Scripts - Fixed Image Names:**
- Changed: `coffee_app:backup` → `coffee_project-app:backup`
- Matches the actual image name docker-compose creates

### Fixed Rollback Flow:
```
1. Git pull → Gets broken code in working directory
2. Deployment fails
3. Rollback tags: coffee_project-app:backup → coffee_project-app:latest
4. Rollback runs: docker-compose up -d --no-build  ← Key change!
5. Docker-compose uses existing image (doesn't rebuild)
6. Container runs with backup image ✅
7. App works with previous version!
```

## Changes Summary

| File | Change | Why |
|------|--------|-----|
| `backup-container.sh` | Use `coffee_project-app:backup` | Match docker-compose image name |
| `rollback-container.sh` | Add `--no-build` flag | Don't rebuild from broken source |
| `rollback-container.sh` | Use `coffee_project-app:backup` | Match docker-compose image name |
| `cleanup-backup.sh` | Use `coffee_project-app:backup` | Match docker-compose image name |

## Testing the Fix

### Deploy Steps:
```bash
# 1. Commit the bug fixes
git add scripts/*.sh coffee_project/app.js
git commit -m "fix: Critical rollback bug - prevent rebuilding from source

- Add --no-build flag to rollback to use backup image
- Fix image names to match docker-compose naming (coffee_project-app)
- Remove breaking change from app.js"

git push origin dev

# 2. Create PR and merge to main
# This will deploy the working version

# 3. After successful deployment, add breaking change again
# 4. Watch rollback restore the GOOD version this time!
```

### Expected Result:
- ✅ Backup created from working version
- ❌ Broken version fails health checks
- 🔄 Rollback restores backup WITHOUT rebuilding
- ✅ App returns to working state

## Why This Bug Was Hard to Spot

1. The rollback logs said "✓ Rollback successful"
2. The container did start successfully  
3. But it was running the WRONG code (rebuilt, not backup)
4. Only testing the actual endpoint revealed the issue

## Credit

User discovered this bug by observing: "When I merged the working version, the website worked. But after rollback, it never came back." 

This observation led to discovering the rebuild issue! 🎯

