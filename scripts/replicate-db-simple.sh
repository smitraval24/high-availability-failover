#!/usr/bin/env bash
# replicate-db.sh - SIMPLIFIED VERSION that actually works
# Replicate database from VCL2 to VCL3

set -euo pipefail

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORKDIR=/tmp/coffee-replication
DUMP_FILE="$WORKDIR/coffee_dev_${TIMESTAMP}.sql.gz"
REMOTE_USER=vpatel29
REMOTE_HOST=152.7.178.91
REMOTE_TMP=/tmp
PROJECT_DIR=~/devops-project/coffee_project

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

# Create work directory
mkdir -p "$WORKDIR"

# Step 1: Dump database from VCL2
log_info "Starting database replication from VCL2 to VCL3..."
log_info "Dumping database from VCL2..."

if ! sudo docker-compose -f "$PROJECT_DIR/docker-compose.yml" exec -T db \
    pg_dump -U postgres coffee_dev | gzip > "$DUMP_FILE"; then
    log_error "Failed to dump database on VCL2"
    rm -f "$DUMP_FILE"
    exit 1
fi

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log_info "Database dump created: $DUMP_FILE ($DUMP_SIZE)"

# Step 2: Copy dump to VCL3
log_info "Transferring dump to VCL3 ($REMOTE_HOST)..."

REMOTE_DUMP_FILE="${REMOTE_TMP}/coffee_dev_${TIMESTAMP}.sql.gz"

if ! scp -q "$DUMP_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DUMP_FILE}"; then
    log_error "Failed to transfer dump to VCL3"
    rm -f "$DUMP_FILE"
    exit 1
fi

log_info "Dump transferred successfully"

# Step 3: Restore on VCL3 (SIMPLIFIED - run commands one at a time)
log_info "Restoring database on VCL3..."

# Ensure DB container is running
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose up -d db" > /dev/null 2>&1

# Wait for PostgreSQL to be ready
log_info "Waiting for PostgreSQL on VCL3..."
for i in {1..30}; do
    if ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db pg_isready -U postgres" > /dev/null 2>&1; then
        log_info "PostgreSQL is ready"
        break
    fi
    sleep 2
done

# Drop and recreate database
log_info "Dropping old database on VCL3..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres -c 'DROP DATABASE IF EXISTS coffee_dev;'" > /dev/null 2>&1

log_info "Creating fresh database on VCL3..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres -c 'CREATE DATABASE coffee_dev;'" > /dev/null 2>&1

# Restore the dump
log_info "Restoring data to VCL3..."
if ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && gunzip < ${REMOTE_DUMP_FILE} | sudo docker-compose exec -T db psql -U postgres coffee_dev" > /dev/null 2>&1; then
    log_info "Database restored successfully on VCL3"
else
    log_error "Failed to restore database on VCL3"
    rm -f "$DUMP_FILE"
    exit 1
fi

# Cleanup remote dump
ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ${REMOTE_DUMP_FILE}" > /dev/null 2>&1

# Step 4: Cleanup local dump
rm -f "$DUMP_FILE"

# Cleanup old dumps (keep last hour only)
find "$WORKDIR" -name "coffee_dev_*.sql.gz" -mmin +60 -delete 2>/dev/null || true
ssh "${REMOTE_USER}@${REMOTE_HOST}" "find /tmp -name 'coffee_dev_*.sql.gz' -mmin +60 -delete" 2>/dev/null || true

log_info "Replication completed successfully!"
log_info "================================================"
