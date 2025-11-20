#!/usr/bin/env bash
# check-replication-health.sh - Monitor database replication health
# Run this anytime to check if replication is working

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Database Replication Health Check ==="
echo ""

# 1. Check if timer is active
echo "1. Timer Status:"
if systemctl is-active --quiet coffee-replication.timer; then
    echo -e "   ${GREEN}✓ Timer is ACTIVE${NC}"
    
    # Show next run time
    NEXT_RUN=$(systemctl list-timers | grep coffee | awk '{print $1, $2, $3, $4, $5}')
    echo "   Next run: $NEXT_RUN"
else
    echo -e "   ${RED}✗ Timer is INACTIVE${NC}"
    echo "   Run: sudo systemctl start coffee-replication.timer"
    exit 1
fi
echo ""

# 2. Check if timer is enabled (starts on boot)
echo "2. Auto-start on Boot:"
if systemctl is-enabled --quiet coffee-replication.timer; then
    echo -e "   ${GREEN}✓ Timer is ENABLED (will start on reboot)${NC}"
else
    echo -e "   ${YELLOW}⚠ Timer is NOT enabled${NC}"
    echo "   Run: sudo systemctl enable coffee-replication.timer"
fi
echo ""

# 3. Check recent replications
echo "3. Recent Replications:"
if [ -f /var/log/coffee-replication/replicate.log ]; then
    # Get last 5 successful replications with timestamps
    echo "   Last 5 successful replications:"
    sudo grep "Replication completed successfully" /var/log/coffee-replication/replicate.log | tail -5 | while read line; do
        echo "   - $line"
    done
    echo ""
    
    # Check if last replication was recent (within 5 minutes)
    LAST_SUCCESS=$(sudo grep "Replication completed successfully" /var/log/coffee-replication/replicate.log | tail -1 | grep -oP '\[\K[^\]]+')
    LAST_TIMESTAMP=$(date -d "$LAST_SUCCESS" +%s 2>/dev/null || echo "0")
    CURRENT_TIMESTAMP=$(date +%s)
    DIFF=$((CURRENT_TIMESTAMP - LAST_TIMESTAMP))
    
    if [ $DIFF -lt 300 ]; then
        echo -e "   ${GREEN}✓ Last replication was $((DIFF/60)) minutes ago (FRESH!)${NC}"
    elif [ $DIFF -lt 600 ]; then
        echo -e "   ${YELLOW}⚠ Last replication was $((DIFF/60)) minutes ago (getting old)${NC}"
    else
        echo -e "   ${RED}✗ Last replication was $((DIFF/60)) minutes ago (STALE!)${NC}"
        echo "   Check for errors in logs"
    fi
else
    echo -e "   ${RED}✗ No log file found${NC}"
    echo "   Log should be at: /var/log/coffee-replication/replicate.log"
fi
echo ""

# 4. Check for recent errors
echo "4. Recent Errors:"
if [ -f /var/log/coffee-replication/replicate.log ]; then
    ERROR_COUNT=$(sudo grep -c "ERROR" /var/log/coffee-replication/replicate.log | tail -100 || echo "0")
    if [ "$ERROR_COUNT" -eq "0" ]; then
        echo -e "   ${GREEN}✓ No errors in recent logs${NC}"
    else
        echo -e "   ${YELLOW}⚠ Found $ERROR_COUNT errors in recent logs${NC}"
        echo "   Last 3 errors:"
        sudo grep "ERROR" /var/log/coffee-replication/replicate.log | tail -3 | while read line; do
            echo "   - $line"
        done
    fi
else
    echo -e "   ${YELLOW}⚠ No log file to check${NC}"
fi
echo ""

# 5. Test connectivity to VCL3
echo "5. VCL3 Connectivity:"
if ping -c 1 -W 2 152.7.178.91 > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ Can reach VCL3 (152.7.178.91)${NC}"
else
    echo -e "   ${RED}✗ Cannot reach VCL3${NC}"
    echo "   Replication will fail until VCL3 is reachable"
fi
echo ""

# Summary
echo "=== Summary ==="
if systemctl is-active --quiet coffee-replication.timer; then
    echo -e "${GREEN}✓ Automatic replication is working!${NC}"
    echo ""
    echo "Monitoring commands:"
    echo "  - Check status:       systemctl status coffee-replication.timer"
    echo "  - View live logs:     sudo tail -f /var/log/coffee-replication/replicate.log"
    echo "  - See all timers:     systemctl list-timers | grep coffee"
    echo "  - Manual run:         sudo systemctl start coffee-replication.service"
else
    echo -e "${RED}✗ Replication needs attention!${NC}"
    echo "Run: sudo systemctl start coffee-replication.timer"
fi

