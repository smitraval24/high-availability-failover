#!/usr/bin/env bash
# reverse-replicate-db.sh - Replicate database from VCL3 to VCL2 during failback
# Run this script on VCL3 when VCL2 comes back online
# This ensures VCL2 gets the latest data from VCL3 before traffic is rerouted

set -euo pipefail

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORKDIR=/tmp/coffee-replication
DUMP_FILE="$WORKDIR/coffee_dev_failback_${TIMESTAMP}.sql.gz"
REMOTE_USER=vpatel29
REMOTE_HOST=152.7.178.106  # VCL2
REMOTE_TMP=/tmp
PROJECT_DIR=~/devops-project/coffee_project

# Colors for logging
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

# Create work directory
mkdir -p "$WORKDIR"

log_info "========================================"
log_info "FAILBACK: Replicating VCL3 -> VCL2"
log_info "========================================"

# Step 1: Dump database from VCL3 (this machine)
log_info "Dumping database from VCL3..."

cd "$PROJECT_DIR"

if ! sudo docker-compose exec -T db \
    pg_dump -U postgres coffee_dev | gzip > "$DUMP_FILE"; then
    log_error "Failed to dump database on VCL3"
    rm -f "$DUMP_FILE"
    exit 1
fi

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log_info "Database dump created: $DUMP_FILE ($DUMP_SIZE)"

# Step 2: Copy dump to VCL2
log_info "Transferring dump to VCL2 ($REMOTE_HOST)..."

if ! scp -q "$DUMP_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP}/"; then
    log_error "Failed to transfer dump to VCL2"
    rm -f "$DUMP_FILE"
    exit 1
fi

log_info "Dump transferred successfully"

# Step 3: Restore on VCL2
log_info "Restoring database on VCL2..."

REMOTE_DUMP_FILE="${REMOTE_TMP}/$(basename "$DUMP_FILE")"

ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" bash -s <<EOF
set -e

REMOTE_DUMP="$REMOTE_DUMP_FILE"
PROJECT_DIR=~/devops-project/coffee_project

echo "[VCL2] Starting database failback restore..."

# Navigate to project directory
cd \${PROJECT_DIR}

# Ensure db container is running
echo "[VCL2] Starting database container..."
sudo docker-compose up -d db

# Wait for postgres to be ready
echo "[VCL2] Waiting for PostgreSQL to be ready..."
RETRIES=30
until sudo docker-compose exec -T db pg_isready -U postgres >/dev/null 2>&1; do
    RETRIES=\$((RETRIES - 1))
    if [ \$RETRIES -le 0 ]; then
        echo "[VCL2] ERROR: PostgreSQL did not start in time"
        exit 1
    fi
    echo "[VCL2] Waiting... (\$RETRIES attempts remaining)"
    sleep 2
done

echo "[VCL2] PostgreSQL is ready. Restoring database..."

# Terminate existing connections to the database
sudo docker-compose exec -T db psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'coffee_dev' AND pid <> pg_backend_pid();" || true

# Drop existing database and recreate (clean restore)
sudo docker-compose exec -T db psql -U postgres -c "DROP DATABASE IF EXISTS coffee_dev;" 2>/dev/null || true
sudo docker-compose exec -T db psql -U postgres -c "CREATE DATABASE coffee_dev;"

# Restore the dump
if gunzip < "\$REMOTE_DUMP" | sudo docker-compose exec -T db psql -U postgres coffee_dev; then
    echo "[VCL2] Database restored successfully from VCL3 failback"

    # Verify restoration
    TABLE_COUNT=\$(sudo docker-compose exec -T db psql -U postgres coffee_dev -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
    COFFEE_COUNT=\$(sudo docker-compose exec -T db psql -U postgres coffee_dev -t -c "SELECT COUNT(*) FROM coffees;" 2>/dev/null || echo "0")
    ORDER_COUNT=\$(sudo docker-compose exec -T db psql -U postgres coffee_dev -t -c "SELECT COUNT(*) FROM orders;" 2>/dev/null || echo "0")
    echo "[VCL2] Database contains \$TABLE_COUNT tables, \$COFFEE_COUNT coffees, \$ORDER_COUNT orders"
else
    echo "[VCL2] ERROR: Failed to restore database"
    exit 1
fi

# Cleanup remote dump
rm -f "\$REMOTE_DUMP"
echo "[VCL2] Cleanup completed"
EOF

if [ $? -eq 0 ]; then
    log_info "Database restored successfully on VCL2 from VCL3"
else
    log_error "Failed to restore database on VCL2"
    rm -f "$DUMP_FILE"
    exit 1
fi

# Step 4: Cleanup local dump
rm -f "$DUMP_FILE"

# Cleanup old dumps (keep last hour only)
find "$WORKDIR" -name "coffee_dev_*.sql.gz" -mmin +60 -delete 2>/dev/null || true

log_info "========================================"
log_info "FAILBACK REPLICATION COMPLETED!"
log_info "VCL2 now has the latest data from VCL3"
log_info "========================================"
