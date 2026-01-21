#!/usr/bin/env bash
# =============================================================================
# rollback-container.sh
# =============================================================================
# Rollback to previous container version
# This script is triggered when health checks fail after deployment
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Load Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source configuration files
if [ -f "$PROJECT_ROOT/config/defaults.env" ]; then
    source "$PROJECT_ROOT/config/defaults.env"
fi

if [ -f "$PROJECT_ROOT/config/config.env" ]; then
    source "$PROJECT_ROOT/config/config.env"
fi

# Configuration
APP_NAME="${APP_NAME:-coffee}"
APP_CONTAINER="${APP_CONTAINER:-${APP_NAME}_app}"
DB_CONTAINER="${DB_CONTAINER:-${APP_NAME}_db}"
APP_PORT="${APP_PORT:-3000}"
HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-/coffees}"
DB_NAME="${DB_NAME:-coffee_dev}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"

PROJECT_DIR="${PROJECT_DIR:-high-availability-failover}"
APP_DIR="${APP_DIR:-coffee_project}"
APP_PATH="$HOME/$PROJECT_DIR/$APP_DIR"
BACKUP_DIR="${BACKUP_DIR:-/tmp/${APP_NAME}_deployment}"
BACKUP_IMAGE="${APP_NAME}_app:backup"
DOCKER_NETWORK="${APP_NAME}_project_default"

# -----------------------------------------------------------------------------
# Colors for output
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
log_error "=== DEPLOYMENT FAILED - INITIATING ROLLBACK ==="

# Check if backup exists
log_info "Checking for backup image..."
sudo docker images | grep -E "backup" || true

# Find backup image
FOUND_BACKUP=""
if sudo docker images | grep -q "${BACKUP_IMAGE}"; then
    FOUND_BACKUP="${BACKUP_IMAGE}"
    log_info "Found backup: $FOUND_BACKUP"
elif sudo docker images | grep -q "coffee_project-app.*backup"; then
    FOUND_BACKUP="coffee_project-app:backup"
    log_info "Found backup: $FOUND_BACKUP"
elif sudo docker images | grep -q "coffee_app.*backup"; then
    FOUND_BACKUP="coffee_app:backup"
    log_info "Found backup: $FOUND_BACKUP"
fi

if [ -z "$FOUND_BACKUP" ]; then
    log_error "No backup image found! Cannot rollback."
    log_error "Available images:"
    sudo docker images
    log_error "Manual intervention required."
    exit 1
fi

log_info "Backup image found: $FOUND_BACKUP. Starting rollback process..."

# Stop the failed new containers
log_info "Stopping failed containers..."
cd "$APP_PATH" 2>/dev/null || cd "$HOME/$PROJECT_DIR/$APP_DIR"
sudo docker compose down || sudo docker-compose down || true

# Remove the failed app container if exists
sudo docker rm -f "${APP_CONTAINER}" 2>/dev/null || true
sudo docker rm -f coffee_app 2>/dev/null || true
sudo docker rm -f coffee_app_rollback 2>/dev/null || true

# Wait a moment for cleanup
sleep 3

# Start just the database first
log_info "Starting database..."
sudo docker compose up -d db || sudo docker-compose up -d db || true

sleep 5

# Check if db is running
if ! sudo docker ps | grep -q "${DB_CONTAINER}\|coffee_db\|db"; then
    log_warn "Database container not running, trying to start it..."
    sudo docker run -d \
        --name "${DB_CONTAINER}" \
        --network "${DOCKER_NETWORK}" \
        -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
        -e POSTGRES_DB="${DB_NAME}" \
        postgres:15-alpine
    sleep 5
fi

# Run the backup app image manually
log_info "Starting app from backup image: $FOUND_BACKUP..."
sudo docker run -d \
    --name "${APP_CONTAINER}" \
    --network "${DOCKER_NETWORK}" \
    -p "${APP_PORT}:${APP_PORT}" \
    -e DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}" \
    -w /app \
    "$FOUND_BACKUP"

# Wait for containers to be ready
log_info "Waiting for application to be ready..."
sleep 10

# Verify the rollback worked
log_info "Verifying rollback..."
MAX_RETRIES=12
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sS -f "http://localhost:${APP_PORT}${HEALTH_ENDPOINT}" > /dev/null 2>&1; then
        log_info "Rollback successful! Application is responding."

        # Check if we can retrieve data
        RESPONSE=$(curl -sS "http://localhost:${APP_PORT}${HEALTH_ENDPOINT}")
        if echo "$RESPONSE" | grep -q "id"; then
            log_info "Application is serving data correctly"
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
