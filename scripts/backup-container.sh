#!/usr/bin/env bash
# =============================================================================
# backup-container.sh
# =============================================================================
# Backup current application container before deployment
# This script should be run on the PRIMARY server before deploying new code
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
BACKUP_DIR="${BACKUP_DIR:-/tmp/${APP_NAME}_deployment}"
BACKUP_IMAGE="${APP_NAME}_app:backup"

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
log_info "Starting container backup process..."

# Check if app container is running (try multiple naming patterns)
CONTAINER_NAME=""
if sudo docker ps | grep -q "${APP_CONTAINER}"; then
    CONTAINER_NAME="${APP_CONTAINER}"
elif sudo docker ps | grep -q "${APP_NAME}_project-app"; then
    CONTAINER_NAME="${APP_NAME}_project-app"
elif sudo docker ps | grep -q "coffee_app"; then
    CONTAINER_NAME="coffee_app"
elif sudo docker ps | grep -q "coffee_project-app"; then
    CONTAINER_NAME="coffee_project-app"
elif sudo docker ps --format "{{.Names}}" | grep -q app; then
    CONTAINER_NAME=$(sudo docker ps --format "{{.Names}}" | grep app | head -1)
fi

if [ -z "$CONTAINER_NAME" ]; then
    log_warn "No app container is running. No backup needed."
    log_info "Running containers:"
    sudo docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
    exit 0
fi

log_info "Found running container: $CONTAINER_NAME"

# Remove any existing backup image
if sudo docker images | grep -q "backup"; then
    log_info "Removing old backup image..."
    sudo docker rmi "${BACKUP_IMAGE}" 2>/dev/null || true
    sudo docker rmi coffee_project-app:backup 2>/dev/null || true
    sudo docker rmi coffee-app-backup:latest 2>/dev/null || true
fi

# Create new backup by committing the running container
log_info "Creating backup of current container..."
if sudo docker commit "$CONTAINER_NAME" "${BACKUP_IMAGE}"; then
    log_info "Backup created successfully: ${BACKUP_IMAGE}"
    sudo docker images | grep backup
else
    log_error "Failed to create backup"
    exit 1
fi

# Save backup metadata
mkdir -p "$BACKUP_DIR"
echo "$(date +%Y%m%d_%H%M%S)" > "$BACKUP_DIR/backup.timestamp"
echo "$CONTAINER_NAME" > "$BACKUP_DIR/backup.container_name"
echo "${BACKUP_IMAGE}" > "$BACKUP_DIR/backup.image_name"

log_info "Backup metadata saved to $BACKUP_DIR"
log_info "Backup process completed successfully!"
