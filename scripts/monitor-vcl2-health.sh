#!/usr/bin/env bash
# monitor-vcl2-health.sh
# Monitors VCL2 health and triggers failover to VCL3 if VCL2 is down
# Run this script on VCL3 as a systemd service

set -uo pipefail

# Configuration
VCL2_HOST="152.7.178.106"
VCL2_PORT="3000"
VCL2_ENDPOINT="http://${VCL2_HOST}:${VCL2_PORT}/coffees"
CHECK_INTERVAL=30  # seconds between health checks
MAX_FAILURES=3     # number of consecutive failures before failover
LOG_FILE="/var/log/vcl-failover/monitor.log"
STATE_FILE="/var/tmp/vcl2-monitor-state"

# Colors for logging
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Initialize log directory
mkdir -p "$(dirname "$LOG_FILE")"
sudo chown $USER:$(id -gn) "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Health check function
check_vcl2_health() {
    # Try HTTP endpoint
    if curl -sf --connect-timeout 5 --max-time 10 "$VCL2_ENDPOINT" > /dev/null 2>&1; then
        return 0  # VCL2 is healthy
    fi

    # If HTTP fails, try ping as backup check
    if ping -c 1 -W 2 "$VCL2_HOST" > /dev/null 2>&1; then
        # Host is up but app might be down
        log "WARN" "VCL2 host is reachable but app endpoint is not responding"
        return 1
    fi

    # Both checks failed
    log "ERROR" "VCL2 is completely unreachable"
    return 1
}

# Check if VCL3 app is already running
is_vcl3_running() {
    if sudo docker ps --filter "name=coffee_app" --filter "status=running" -q | grep -q .; then
        return 0  # VCL3 app is running
    fi
    return 1
}

# Check if cloudflared is running
ensure_cloudflared_running() {
    if systemctl is-active --quiet cloudflared; then
        log "INFO" "Cloudflared tunnel is running"
        return 0
    else
        log "WARN" "Cloudflared not running, attempting to start..."
        if sudo systemctl start cloudflared; then
            sleep 3
            if systemctl is-active --quiet cloudflared; then
                log "SUCCESS" "Cloudflared tunnel started successfully"
                return 0
            fi
        fi
        log "ERROR" "Failed to start cloudflared tunnel"
        return 1
    fi
}

# Failover function - starts VCL3 application
perform_failover() {
    log "CRITICAL" "========================================="
    log "CRITICAL" "INITIATING FAILOVER TO VCL3"
    log "CRITICAL" "========================================="

    # Navigate to project directory
    cd "$HOME/devops-project/coffee_project" || {
        log "ERROR" "Failed to navigate to project directory"
        return 1
    }

    # Pull latest code (in case there were updates)
    log "INFO" "Pulling latest code from main branch..."
    cd "$HOME/devops-project"
    git pull origin main || log "WARN" "Git pull failed, using existing code"

    # Start Docker containers
    log "INFO" "Starting Docker containers on VCL3..."
    cd "$HOME/devops-project/coffee_project"

    if sudo docker-compose up -d --build; then
        log "SUCCESS" "VCL3 application started successfully"

        # Wait for app to be ready
        sleep 10

        # Verify VCL3 is responding
        if curl -sf --connect-timeout 5 http://localhost:3000/coffees > /dev/null 2>&1; then
            log "SUCCESS" "VCL3 health check passed - application is serving requests"

            # Ensure cloudflared is running for Cloudflare tunnel routing
            ensure_cloudflared_running

            log "SUCCESS" "Failover complete! VCL3 is now serving traffic via Cloudflare tunnel"
            log "SUCCESS" "Public URL: https://devopsproject.dpdns.org"
            return 0
        else
            log "ERROR" "VCL3 started but health check failed"
            return 1
        fi
    else
        log "ERROR" "Failed to start VCL3 application"
        return 1
    fi
}

# Recovery function - syncs database and stops VCL3 when VCL2 comes back
perform_recovery() {
    log "INFO" "========================================="
    log "INFO" "VCL2 HAS RECOVERED - INITIATING FAILBACK"
    log "INFO" "========================================="

    SCRIPT_DIR="$HOME/devops-project/scripts"

    # Step 1: Sync VCL3's database to VCL2 before stopping
    log "INFO" "Syncing VCL3 database to VCL2 before failback..."
    if [ -x "$SCRIPT_DIR/failback-to-vcl2.sh" ]; then
        if "$SCRIPT_DIR/failback-to-vcl2.sh"; then
            log "SUCCESS" "Failback completed - VCL2 has latest data from VCL3"
            return 0
        else
            log "ERROR" "Failback script failed"
            log "WARN" "VCL3 will continue serving traffic until failback succeeds"
            return 1
        fi
    else
        # Fallback: Use reverse-replicate-db.sh directly if failback script not available
        if [ -x "$SCRIPT_DIR/reverse-replicate-db.sh" ]; then
            log "INFO" "Using reverse replication script..."
            if "$SCRIPT_DIR/reverse-replicate-db.sh"; then
                log "SUCCESS" "Database synced to VCL2"

                # Now stop VCL3 app
                cd "$HOME/devops-project/coffee_project" || return 1
                if sudo docker-compose stop app; then
                    log "SUCCESS" "VCL3 application stopped - VCL2 is primary again"
                    return 0
                fi
            fi
        fi

        log "ERROR" "No failback/replication script available"
        return 1
    fi
}

# Main monitoring loop
main() {
    log "INFO" "Starting VCL2 health monitor on VCL3"
    log "INFO" "Monitoring endpoint: $VCL2_ENDPOINT"
    log "INFO" "Check interval: ${CHECK_INTERVAL}s"
    log "INFO" "Failure threshold: $MAX_FAILURES consecutive failures"

    failure_count=0
    vcl3_active=false

    # Check initial state
    if is_vcl3_running; then
        vcl3_active=true
        log "INFO" "VCL3 is currently running (failover already active)"
    fi

    while true; do
        if check_vcl2_health; then
            # VCL2 is healthy
            if [ "$failure_count" -gt 0 ]; then
                log "INFO" "VCL2 health check passed (was failing, now recovered)"
            fi

            failure_count=0

            # If VCL3 is active and VCL2 has recovered, stop VCL3
            if [ "$vcl3_active" = true ]; then
                log "INFO" "VCL2 has recovered - initiating recovery process"
                if perform_recovery; then
                    vcl3_active=false
                fi
            fi

        else
            # VCL2 health check failed
            ((failure_count++))
            log "WARN" "VCL2 health check failed ($failure_count/$MAX_FAILURES)"

            # Trigger failover if threshold reached and VCL3 not already active
            if [ "$failure_count" -ge "$MAX_FAILURES" ] && [ "$vcl3_active" = false ]; then
                log "CRITICAL" "VCL2 failure threshold reached!"

                if perform_failover; then
                    vcl3_active=true
                    failure_count=0  # Reset counter
                else
                    log "ERROR" "Failover attempt failed, will retry on next cycle"
                fi
            fi
        fi

        # Save state
        echo "vcl3_active=$vcl3_active" > "$STATE_FILE"
        echo "failure_count=$failure_count" >> "$STATE_FILE"

        # Wait before next check
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals for graceful shutdown
trap 'log "INFO" "Monitor stopped by signal"; exit 0' SIGTERM SIGINT

# Start monitoring
main
