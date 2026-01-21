#!/usr/bin/env bash
# =============================================================================
# monitor-primary-health.sh
# =============================================================================
# Monitors primary server health and triggers failover to backup if primary is down
# Run this script on the BACKUP server as a systemd service
#
# Configuration is loaded from config/config.env or can be set via environment
# =============================================================================

set -uo pipefail

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
# Configuration (can be overridden by config.env or environment)
# -----------------------------------------------------------------------------
PRIMARY_HOST="${PRIMARY_HOST:-}"
APP_PORT="${APP_PORT:-3000}"
HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-/coffees}"
PRIMARY_ENDPOINT="http://${PRIMARY_HOST}:${APP_PORT}${HEALTH_ENDPOINT}"

CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-30}"
MAX_FAILURES="${FAIL_THRESHOLD:-3}"

APP_NAME="${APP_NAME:-coffee}"
APP_CONTAINER="${APP_CONTAINER:-${APP_NAME}_app}"
PROJECT_DIR="${PROJECT_DIR:-high-availability-failover}"
APP_DIR="${APP_DIR:-coffee_project}"

LOG_DIR="${LOG_DIR:-/var/log/${APP_NAME}-failover}"
LOG_FILE="${LOG_DIR}/monitor.log"
STATE_FILE="/var/tmp/${APP_NAME}-monitor-state"

# Domain for public URL (optional)
DOMAIN_NAME="${DOMAIN_NAME:-}"

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
if [ -z "$PRIMARY_HOST" ]; then
    echo "ERROR: PRIMARY_HOST is not configured"
    echo "Please set PRIMARY_HOST in config/config.env or as an environment variable"
    exit 1
fi

# -----------------------------------------------------------------------------
# Colors for logging
# -----------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Initialize log directory
mkdir -p "$LOG_DIR"
sudo chown $USER:$(id -gn) "$LOG_DIR" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Logging function
# -----------------------------------------------------------------------------
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# Health check function
# -----------------------------------------------------------------------------
check_primary_health() {
    # Try HTTP endpoint
    if curl -sf --connect-timeout 5 --max-time 10 "$PRIMARY_ENDPOINT" > /dev/null 2>&1; then
        return 0  # Primary is healthy
    fi

    # If HTTP fails, try ping as backup check
    if ping -c 1 -W 2 "$PRIMARY_HOST" > /dev/null 2>&1; then
        # Host is up but app might be down
        log "WARN" "Primary host is reachable but app endpoint is not responding"
        return 1
    fi

    # Both checks failed
    log "ERROR" "Primary server is completely unreachable"
    return 1
}

# -----------------------------------------------------------------------------
# Check if backup app is already running
# -----------------------------------------------------------------------------
is_backup_running() {
    if sudo docker ps --filter "name=${APP_CONTAINER}" --filter "status=running" -q | grep -q .; then
        return 0  # Backup app is running
    fi
    return 1
}

# -----------------------------------------------------------------------------
# Check if cloudflared is running (optional)
# -----------------------------------------------------------------------------
ensure_cloudflared_running() {
    if ! command -v systemctl &> /dev/null; then
        return 0  # systemd not available, skip
    fi

    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        log "INFO" "Cloudflared tunnel is running"
        return 0
    else
        log "WARN" "Cloudflared not running, attempting to start..."
        if sudo systemctl start cloudflared 2>/dev/null; then
            sleep 3
            if systemctl is-active --quiet cloudflared; then
                log "SUCCESS" "Cloudflared tunnel started successfully"
                return 0
            fi
        fi
        log "WARN" "Cloudflared not available or failed to start (non-critical)"
        return 0  # Non-critical, continue without it
    fi
}

# -----------------------------------------------------------------------------
# Failover function - starts backup application
# -----------------------------------------------------------------------------
perform_failover() {
    log "CRITICAL" "========================================="
    log "CRITICAL" "INITIATING FAILOVER TO BACKUP SERVER"
    log "CRITICAL" "========================================="

    local project_path="$HOME/$PROJECT_DIR"
    local app_path="$project_path/$APP_DIR"

    # Navigate to project directory
    cd "$app_path" || {
        log "ERROR" "Failed to navigate to project directory: $app_path"
        return 1
    }

    # Pull latest code (in case there were updates)
    log "INFO" "Pulling latest code from main branch..."
    cd "$project_path"
    git pull origin main || log "WARN" "Git pull failed, using existing code"

    # Start Docker containers
    log "INFO" "Starting Docker containers on backup server..."
    cd "$app_path"

    if sudo docker-compose up -d --build; then
        log "SUCCESS" "Backup application started successfully"

        # Wait for app to be ready
        sleep 10

        # Verify backup is responding
        if curl -sf --connect-timeout 5 "http://localhost:${APP_PORT}${HEALTH_ENDPOINT}" > /dev/null 2>&1; then
            log "SUCCESS" "Backup health check passed - application is serving requests"

            # Ensure cloudflared is running for Cloudflare tunnel routing (if configured)
            ensure_cloudflared_running

            log "SUCCESS" "Failover complete! Backup server is now serving traffic"
            if [ -n "$DOMAIN_NAME" ]; then
                log "SUCCESS" "Public URL: https://${DOMAIN_NAME}"
            fi
            return 0
        else
            log "ERROR" "Backup started but health check failed"
            return 1
        fi
    else
        log "ERROR" "Failed to start backup application"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Recovery function - syncs database and stops backup when primary comes back
# -----------------------------------------------------------------------------
perform_recovery() {
    log "INFO" "========================================="
    log "INFO" "PRIMARY HAS RECOVERED - INITIATING FAILBACK"
    log "INFO" "========================================="

    local scripts_dir="$HOME/$PROJECT_DIR/scripts"
    local app_path="$HOME/$PROJECT_DIR/$APP_DIR"

    # Step 1: Sync backup's database to primary before stopping
    log "INFO" "Syncing backup database to primary before failback..."
    if [ -x "$scripts_dir/failback-to-primary.sh" ]; then
        if "$scripts_dir/failback-to-primary.sh"; then
            log "SUCCESS" "Failback completed - primary has latest data from backup"
            return 0
        else
            log "ERROR" "Failback script failed"
            log "WARN" "Backup will continue serving traffic until failback succeeds"
            return 1
        fi
    else
        # Fallback: Use reverse-replicate-db.sh directly if failback script not available
        if [ -x "$scripts_dir/reverse-replicate-db.sh" ]; then
            log "INFO" "Using reverse replication script..."
            if "$scripts_dir/reverse-replicate-db.sh"; then
                log "SUCCESS" "Database synced to primary"

                # Now stop backup app
                cd "$app_path" || return 1
                if sudo docker-compose stop app; then
                    log "SUCCESS" "Backup application stopped - primary is active again"
                    return 0
                fi
            fi
        fi

        log "ERROR" "No failback/replication script available"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Main monitoring loop
# -----------------------------------------------------------------------------
main() {
    log "INFO" "Starting primary server health monitor"
    log "INFO" "Monitoring endpoint: $PRIMARY_ENDPOINT"
    log "INFO" "Check interval: ${CHECK_INTERVAL}s"
    log "INFO" "Failure threshold: $MAX_FAILURES consecutive failures"

    failure_count=0
    backup_active=false

    # Check initial state
    if is_backup_running; then
        backup_active=true
        log "INFO" "Backup is currently running (failover already active)"
    fi

    while true; do
        if check_primary_health; then
            # Primary is healthy
            if [ "$failure_count" -gt 0 ]; then
                log "INFO" "Primary health check passed (was failing, now recovered)"
            fi

            failure_count=0

            # If backup is active and primary has recovered, stop backup
            if [ "$backup_active" = true ]; then
                log "INFO" "Primary has recovered - initiating recovery process"
                if perform_recovery; then
                    backup_active=false
                fi
            fi

        else
            # Primary health check failed
            ((failure_count++))
            log "WARN" "Primary health check failed ($failure_count/$MAX_FAILURES)"

            # Trigger failover if threshold reached and backup not already active
            if [ "$failure_count" -ge "$MAX_FAILURES" ] && [ "$backup_active" = false ]; then
                log "CRITICAL" "Primary failure threshold reached!"

                if perform_failover; then
                    backup_active=true
                    failure_count=0  # Reset counter
                else
                    log "ERROR" "Failover attempt failed, will retry on next cycle"
                fi
            fi
        fi

        # Save state
        echo "backup_active=$backup_active" > "$STATE_FILE"
        echo "failure_count=$failure_count" >> "$STATE_FILE"

        # Wait before next check
        sleep "$CHECK_INTERVAL"
    done
}

# -----------------------------------------------------------------------------
# Handle signals for graceful shutdown
# -----------------------------------------------------------------------------
trap 'log "INFO" "Monitor stopped by signal"; exit 0' SIGTERM SIGINT

# Start monitoring
main
