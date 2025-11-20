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

# Check if backup exists
if ! docker images | grep -q "coffee_app.*backup"; then
    log_error "No backup image found! Cannot rollback."
    log_error "Manual intervention required."
    exit 1
fi

log_info "Backup image found. Starting rollback process..."

# Stop the failed new containers
log_info "Stopping failed containers..."
cd "$PROJECT_DIR"
sudo docker-compose down || true

# Wait a moment for cleanup
sleep 3

# Tag the backup as latest (this makes docker-compose use it)
log_info "Restoring backup image as latest..."
docker tag coffee_app:backup coffee_app:latest

# Restart containers with the backed-up version
log_info "Starting containers with backed-up version..."
if sudo docker-compose up -d; then
    log_info "Containers started with backup version"
else
    log_error "Failed to start containers with backup"
    exit 1
fi

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

