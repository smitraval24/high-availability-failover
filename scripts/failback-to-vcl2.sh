#!/usr/bin/env bash
# failback-to-vcl2.sh - Handle VCL2 recovery and traffic rerouting
# Run this script on VCL3 when VCL2 comes back online
# This script:
#   1. Verifies VCL2 is healthy
#   2. Syncs VCL3's database to VCL2 (reverse replication)
#   3. Starts VCL2's app container
#   4. Verifies VCL2 app health
#   5. Reroutes traffic back to VCL2
#   6. Stops VCL3's app container (back to cold standby)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
VCL2_HOST=152.7.178.106
VCL2_USER=vpatel29
VCL2_APP_URL="http://${VCL2_HOST}:3000/coffees"
HEALTH_CHECK_RETRIES=12
HEALTH_CHECK_INTERVAL=5

# Colors for logging
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] STEP:${NC} $1"
}

check_vcl2_connectivity() {
    log_step "Checking VCL2 connectivity..."
    if ! ping -c 3 "$VCL2_HOST" > /dev/null 2>&1; then
        log_error "Cannot reach VCL2 at $VCL2_HOST"
        return 1
    fi

    if ! nc -zv -w 5 "$VCL2_HOST" 22 > /dev/null 2>&1; then
        log_error "SSH port not accessible on VCL2"
        return 1
    fi

    log_info "VCL2 is reachable"
    return 0
}

check_vcl2_db_health() {
    log_step "Checking VCL2 database health..."

    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${VCL2_USER}@${VCL2_HOST}" bash -s <<'EOF'
cd ~/devops-project/coffee_project
sudo docker-compose up -d db

# Wait for postgres to be ready
RETRIES=15
until sudo docker-compose exec -T db pg_isready -U postgres >/dev/null 2>&1; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -le 0 ]; then
        echo "Database not ready"
        exit 1
    fi
    sleep 2
done
echo "Database ready"
EOF

    if [ $? -eq 0 ]; then
        log_info "VCL2 database is healthy"
        return 0
    else
        log_error "VCL2 database is not healthy"
        return 1
    fi
}

sync_database_to_vcl2() {
    log_step "Syncing VCL3 database to VCL2..."

    if ! "$SCRIPT_DIR/reverse-replicate-db.sh"; then
        log_error "Failed to sync database to VCL2"
        return 1
    fi

    log_info "Database synced successfully"
    return 0
}

start_vcl2_app() {
    log_step "Starting VCL2 application..."

    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${VCL2_USER}@${VCL2_HOST}" bash -s <<'EOF'
cd ~/devops-project/coffee_project
echo "Starting app container..."
sudo docker-compose up -d app
echo "Waiting for app to start..."
sleep 10
sudo docker-compose ps
EOF

    if [ $? -eq 0 ]; then
        log_info "VCL2 application started"
        return 0
    else
        log_error "Failed to start VCL2 application"
        return 1
    fi
}

verify_vcl2_app_health() {
    log_step "Verifying VCL2 application health..."

    for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
        if curl -sS -f "$VCL2_APP_URL" > /dev/null 2>&1; then
            log_info "VCL2 application is healthy (attempt $i/$HEALTH_CHECK_RETRIES)"
            return 0
        fi
        log_warn "VCL2 app not ready yet (attempt $i/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done

    log_error "VCL2 application health check failed after $HEALTH_CHECK_RETRIES attempts"
    return 1
}

reroute_traffic_to_vcl2() {
    log_step "Rerouting traffic to VCL2..."

    # Stop cloudflared tunnel pointing to VCL3 (if running)
    if pgrep -f "cloudflared.*tunnel" > /dev/null 2>&1; then
        log_info "Stopping VCL3 cloudflared tunnel..."
        sudo pkill -f "cloudflared.*tunnel" || true
        sleep 2
    fi

    # Start cloudflared tunnel on VCL2
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${VCL2_USER}@${VCL2_HOST}" bash -s <<'EOF'
# Check if tunnel is already running on VCL2
if pgrep -f "cloudflared.*tunnel" > /dev/null 2>&1; then
    echo "Cloudflared tunnel already running on VCL2"
else
    echo "Starting cloudflared tunnel on VCL2..."
    cd ~/devops-project
    if [ -f scripts/setup-cloudflare-tunnel.sh ]; then
        chmod +x scripts/setup-cloudflare-tunnel.sh
        nohup ./scripts/setup-cloudflare-tunnel.sh > /tmp/cloudflared.log 2>&1 &
        sleep 5
        echo "Cloudflared tunnel started"
    else
        echo "Warning: Cloudflare tunnel script not found"
    fi
fi
EOF

    log_info "Traffic rerouted to VCL2"
    return 0
}

stop_vcl3_app() {
    log_step "Stopping VCL3 application (back to cold standby)..."

    cd ~/devops-project/coffee_project
    sudo docker-compose stop app || true

    log_info "VCL3 app stopped. VCL3 is now in cold standby mode."
    log_info "Note: VCL3 database container remains running for faster failover"
}

resume_normal_replication() {
    log_step "Resuming normal VCL2 -> VCL3 replication..."

    # The systemd timer should already be set up on VCL2
    # Just verify it's running
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${VCL2_USER}@${VCL2_HOST}" bash -s <<'EOF'
if systemctl is-active --quiet coffee-replication.timer 2>/dev/null; then
    echo "Replication timer is active on VCL2"
else
    echo "Warning: Replication timer not active. You may need to start it manually:"
    echo "  sudo systemctl start coffee-replication.timer"
fi
EOF

    log_info "Normal replication check complete"
}

# Main execution
main() {
    echo ""
    log_info "=========================================="
    log_info "FAILBACK TO VCL2 - Starting"
    log_info "=========================================="
    echo ""

    # Step 1: Check VCL2 connectivity
    if ! check_vcl2_connectivity; then
        log_error "VCL2 is not reachable. Failback aborted."
        exit 1
    fi

    # Step 2: Check VCL2 database health
    if ! check_vcl2_db_health; then
        log_error "VCL2 database is not healthy. Failback aborted."
        exit 1
    fi

    # Step 3: Sync database from VCL3 to VCL2
    if ! sync_database_to_vcl2; then
        log_error "Database sync failed. Failback aborted."
        exit 1
    fi

    # Step 4: Start VCL2 application
    if ! start_vcl2_app; then
        log_error "Failed to start VCL2 app. Failback aborted."
        exit 1
    fi

    # Step 5: Verify VCL2 app health
    if ! verify_vcl2_app_health; then
        log_error "VCL2 app health check failed. Failback aborted."
        log_warn "VCL3 will continue serving traffic"
        exit 1
    fi

    # Step 6: Reroute traffic to VCL2
    reroute_traffic_to_vcl2

    # Step 7: Stop VCL3 app (back to cold standby)
    stop_vcl3_app

    # Step 8: Resume normal replication
    resume_normal_replication

    echo ""
    log_info "=========================================="
    log_info "FAILBACK COMPLETE!"
    log_info "=========================================="
    log_info "VCL2 is now the primary server"
    log_info "VCL3 is back to cold standby mode"
    log_info "Normal replication (VCL2->VCL3) should resume"
    echo ""
}

main "$@"
