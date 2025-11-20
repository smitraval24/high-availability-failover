#!/usr/bin/env bash
# backup-container.sh - Backup current coffee_app container before deployment
# This script should be run on VCL2 before deploying new code

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

log_info "Starting container backup process..."

# Check if coffee_app container is running
if ! docker ps | grep -q coffee_app; then
    log_warn "coffee_app container is not running. No backup needed."
    exit 0
fi

# Get current container ID
CONTAINER_ID=$(docker ps --filter "name=coffee_app" --format "{{.ID}}")
log_info "Found running container: $CONTAINER_ID"

# Remove any existing backup image
if docker images | grep -q "coffee_app.*backup"; then
    log_info "Removing old backup image..."
    docker rmi coffee_app:backup 2>/dev/null || true
fi

# Create new backup by committing the running container
log_info "Creating backup of current container..."
if docker commit coffee_app coffee_app:backup; then
    log_info "✓ Backup created successfully: coffee_app:backup"
else
    log_error "Failed to create backup"
    exit 1
fi

# Save backup metadata
BACKUP_DIR=/tmp/coffee_deployment
mkdir -p "$BACKUP_DIR"
echo "$(date +%Y%m%d_%H%M%S)" > "$BACKUP_DIR/backup.timestamp"
echo "$CONTAINER_ID" > "$BACKUP_DIR/backup.container_id"

log_info "Backup metadata saved to $BACKUP_DIR"
log_info "Backup process completed successfully!"

