#!/usr/bin/env bash
# rollback-container.sh - Rollback to previous container version
# This script is triggered when health checks fail after deployment

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

PROJECT_DIR=~/devops-project/coffee_project
BACKUP_DIR=/tmp/coffee_deployment

log_error "=== DEPLOYMENT FAILED - INITIATING ROLLBACK ==="

# Check if backup exists (use sudo)
log_info "Checking for backup image..."
sudo docker images | grep -E "backup" || true

# Find backup image using simple grep (checking output from docker images)
BACKUP_IMAGE=""
if sudo docker images | grep -q "coffee_project-app.*backup"; then
    BACKUP_IMAGE="coffee_project-app:backup"
    log_info "Found backup: $BACKUP_IMAGE"
elif sudo docker images | grep -q "coffee_app.*backup"; then
    BACKUP_IMAGE="coffee_app:backup"
    log_info "Found backup: $BACKUP_IMAGE"
fi

if [ -z "$BACKUP_IMAGE" ]; then
    log_error "No backup image found! Cannot rollback."
    log_error "Available images:"
    sudo docker images
    log_error "Manual intervention required."
    exit 1
fi

log_info "Backup image found: $BACKUP_IMAGE. Starting rollback process..."

# Stop the failed new containers
log_info "Stopping failed containers..."
cd "$PROJECT_DIR"
sudo docker compose down || sudo docker-compose down || true

# Remove the failed app container if exists
sudo docker rm -f coffee_app 2>/dev/null || true
sudo docker rm -f coffee_app_rollback 2>/dev/null || true

# Wait a moment for cleanup
sleep 3

# Start just the database first
log_info "Starting database..."
sudo docker compose up -d db || sudo docker-compose up -d db || true

sleep 5

# Check if db is running
if ! sudo docker ps | grep -q "coffee_db\|db"; then
    log_warn "Database container not running, trying to start it..."
    sudo docker run -d \
        --name coffee_db \
        --network coffee_project_default \
        -e POSTGRES_PASSWORD=postgres \
        -e POSTGRES_DB=coffee_dev \
        postgres:15-alpine
    sleep 5
fi

# Run the backup app image manually (use original CMD from image)
log_info "Starting app from backup image: $BACKUP_IMAGE..."
sudo docker run -d \
    --name coffee_app \
    --network coffee_project_default \
    -p 3000:3000 \
    -e DATABASE_URL=postgresql://postgres:postgres@db:5432/coffee_dev \
    -w /app \
    "$BACKUP_IMAGE"

# Wait for containers to be ready
log_info "Waiting for application to be ready..."
sleep 10

# Verify the rollback worked
log_info "Verifying rollback..."
MAX_RETRIES=12
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sS -f http://localhost:3000/coffees > /dev/null 2>&1; then
        log_info "✓ Rollback successful! Application is responding."
        
        # Check if we can retrieve coffees
        RESPONSE=$(curl -sS http://localhost:3000/coffees)
        if echo "$RESPONSE" | grep -q "id"; then
            log_info "✓ Application is serving data correctly"
            log_info "=== ROLLBACK COMPLETED SUCCESSFULLY ==="
            exit 0
        fi
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_warn "Application not ready yet ($RETRY_COUNT/$MAX_RETRIES)..."
    sleep 5
done

log_error "Rollback verification failed - application not responding after rollback"
log_error "Manual intervention required!"
exit 1

