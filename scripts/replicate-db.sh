#!/usr/bin/env bash
# =============================================================================
# replicate-db.sh
# =============================================================================
# Replicate database from PRIMARY to BACKUP server
# Run this script on PRIMARY server via cron or systemd timer
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

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
APP_NAME="${APP_NAME:-coffee}"
DB_NAME="${DB_NAME:-coffee_dev}"
DB_USER="${DB_USER:-postgres}"

BACKUP_HOST="${BACKUP_HOST:-}"
BACKUP_USER="${BACKUP_USER:-}"

PROJECT_DIR="${PROJECT_DIR:-high-availability-failover}"
APP_DIR="${APP_DIR:-coffee_project}"
LOCAL_PROJECT_PATH="$HOME/$PROJECT_DIR/$APP_DIR"

REPLICATION_DIR="${REPLICATION_DIR:-/tmp/${APP_NAME}-replication}"
DUMP_FILE="$REPLICATION_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"
REMOTE_TMP=/tmp

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
if [ -z "$BACKUP_HOST" ]; then
    echo "ERROR: BACKUP_HOST is not configured"
    echo "Please set BACKUP_HOST in config/config.env"
    exit 1
fi

if [ -z "$BACKUP_USER" ]; then
    echo "ERROR: BACKUP_USER is not configured"
    echo "Please set BACKUP_USER in config/config.env"
    exit 1
fi

# -----------------------------------------------------------------------------
# Colors for logging
# -----------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Create work directory
mkdir -p "$REPLICATION_DIR"

# Step 1: Dump database from primary server
log_info "Starting database replication from primary to backup..."
log_info "Dumping database from primary server..."

if ! sudo docker-compose -f "$LOCAL_PROJECT_PATH/docker-compose.yml" exec -T db \
    pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$DUMP_FILE"; then
    log_error "Failed to dump database on primary"
    rm -f "$DUMP_FILE"
    exit 1
fi

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log_info "Database dump created: $DUMP_FILE ($DUMP_SIZE)"

# Step 2: Copy dump to backup server
log_info "Transferring dump to backup server ($BACKUP_HOST)..."

if ! scp -q "$DUMP_FILE" "${BACKUP_USER}@${BACKUP_HOST}:${REMOTE_TMP}/"; then
    log_error "Failed to transfer dump to backup server"
    rm -f "$DUMP_FILE"
    exit 1
fi

log_info "Dump transferred successfully"

# Step 3: Restore on backup server
log_info "Restoring database on backup server..."

REMOTE_DUMP_FILE="${REMOTE_TMP}/$(basename "$DUMP_FILE")"
REMOTE_PROJECT_PATH="\$HOME/$PROJECT_DIR/$APP_DIR"

ssh -o StrictHostKeyChecking=no "${BACKUP_USER}@${BACKUP_HOST}" bash -s <<EOF
set -e

REMOTE_DUMP="$REMOTE_DUMP_FILE"
PROJECT_PATH="$REMOTE_PROJECT_PATH"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"

echo "[BACKUP] Starting database replication restore..."

# Navigate to project directory
cd "\${PROJECT_PATH}"

# Ensure db container is running
echo "[BACKUP] Starting database container..."
sudo docker-compose up -d db

# Wait for postgres to be ready
echo "[BACKUP] Waiting for PostgreSQL to be ready..."
RETRIES=30
until sudo docker-compose exec -T db pg_isready -U "\$DB_USER" >/dev/null 2>&1; do
    RETRIES=\$((RETRIES - 1))
    if [ \$RETRIES -le 0 ]; then
        echo "[BACKUP] ERROR: PostgreSQL did not start in time"
        exit 1
    fi
    echo "[BACKUP] Waiting... (\$RETRIES attempts remaining)"
    sleep 2
done

echo "[BACKUP] PostgreSQL is ready. Restoring database..."

# Terminate existing connections to the database
sudo docker-compose exec -T db psql -U "\$DB_USER" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '\$DB_NAME' AND pid <> pg_backend_pid();" || true

# Drop existing database and recreate (clean restore)
sudo docker-compose exec -T db psql -U "\$DB_USER" -c "DROP DATABASE IF EXISTS \$DB_NAME;" 2>/dev/null || true
sudo docker-compose exec -T db psql -U "\$DB_USER" -c "CREATE DATABASE \$DB_NAME;"

# Restore the dump
if gunzip < "\$REMOTE_DUMP" | sudo docker-compose exec -T db psql -U "\$DB_USER" "\$DB_NAME"; then
    echo "[BACKUP] Database restored successfully"

    # Verify restoration
    TABLE_COUNT=\$(sudo docker-compose exec -T db psql -U "\$DB_USER" "\$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
    echo "[BACKUP] Database contains \$TABLE_COUNT tables"
else
    echo "[BACKUP] ERROR: Failed to restore database"
    exit 1
fi

# Cleanup remote dump
rm -f "\$REMOTE_DUMP"
echo "[BACKUP] Cleanup completed"

# Note: Leaving DB container running for next replication (faster)
# App container remains stopped (cold standby)
EOF

if [ $? -eq 0 ]; then
    log_info "Database restored successfully on backup server"
else
    log_error "Failed to restore database on backup server"
    rm -f "$DUMP_FILE"
    exit 1
fi

# Step 4: Cleanup local dump
rm -f "$DUMP_FILE"

# Cleanup old dumps (keep last hour only)
find "$REPLICATION_DIR" -name "${DB_NAME}_*.sql.gz" -mmin +60 -delete 2>/dev/null || true

log_info "Replication completed successfully!"
log_info "================================================"
