#!/usr/bin/env bash
# cleanup-backup.sh - Remove backup after successful deployment
# This script runs only when deployment and health checks pass

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

BACKUP_DIR=/tmp/coffee_deployment

log_info "Cleaning up deployment backup..."

# Remove backup image
if docker images | grep -q "coffee_project-app.*backup"; then
    log_info "Removing backup image..."
    if docker rmi coffee_project-app:backup 2>/dev/null; then
        log_info "✓ Backup image removed"
    else
        log_warn "Could not remove backup image (may not exist)"
    fi
else
    log_warn "No backup image found to remove"
fi

# Remove backup metadata
if [ -d "$BACKUP_DIR" ]; then
    log_info "Removing backup metadata..."
    rm -f "$BACKUP_DIR/backup.timestamp"
    rm -f "$BACKUP_DIR/backup.container_id"
    log_info "✓ Backup metadata removed"
fi

log_info "Cleanup completed successfully!"

