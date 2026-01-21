#!/bin/bash
# =============================================================================
# local-bootstrap.sh
# =============================================================================
# Run this from your LOCAL machine (Laptop/Desktop)
# This script sets up SSH connectivity between your servers.
#
# Configuration is loaded from config/config.env or can be set via environment
# =============================================================================

set -e

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
# Configuration (can be overridden by config.env or passed as arguments)
# -----------------------------------------------------------------------------
# Default to environment variables or prompt user
SSH_USER="${PRIMARY_USER:-}"
PRIMARY_IP="${PRIMARY_HOST:-}"
BACKUP_IP="${BACKUP_HOST:-}"
LB_IP="${LB_HOST:-}"

# If not set, prompt the user
if [ -z "$SSH_USER" ]; then
    read -p "Enter SSH username: " SSH_USER
fi

if [ -z "$PRIMARY_IP" ]; then
    read -p "Enter PRIMARY server IP: " PRIMARY_IP
fi

if [ -z "$BACKUP_IP" ]; then
    read -p "Enter BACKUP server IP: " BACKUP_IP
fi

# Load balancer is optional
if [ -z "$LB_IP" ]; then
    read -p "Enter LOAD BALANCER server IP (press Enter to skip): " LB_IP
fi

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
if [ -z "$SSH_USER" ] || [ -z "$PRIMARY_IP" ] || [ -z "$BACKUP_IP" ]; then
    echo "ERROR: SSH_USER, PRIMARY_IP, and BACKUP_IP are required"
    echo ""
    echo "You can set these in config/config.env:"
    echo "  PRIMARY_USER=your-username"
    echo "  PRIMARY_HOST=your-primary-ip"
    echo "  BACKUP_HOST=your-backup-ip"
    echo "  LB_HOST=your-loadbalancer-ip  (optional)"
    exit 1
fi

echo "=========================================="
echo "  SERVER CONNECTIVITY BOOTSTRAP"
echo "=========================================="
echo "This script will:"
echo "1. Generate an SSH key on PRIMARY server (Control Node)"
echo "2. Copy that key to all other servers"
echo "3. Flush firewalls on all servers"
echo ""
echo "Configuration:"
echo "  User:          $SSH_USER"
echo "  Primary:       $PRIMARY_IP"
echo "  Backup:        $BACKUP_IP"
if [ -n "$LB_IP" ]; then
    echo "  Load Balancer: $LB_IP"
fi
echo ""
echo "You will be asked for your server password ONCE (if sshpass is installed)."
echo "=========================================="

# Check for sshpass
if ! command -v sshpass &> /dev/null; then
    echo "WARNING: 'sshpass' is not installed on this machine."
    echo "   You will need to enter your password multiple times."
    echo "   (To fix this: install sshpass via your package manager)"
    SSHPASS_CMD=""
else
    read -sp "Enter your server password: " SERVER_PASS
    echo ""
    SSHPASS_CMD="sshpass -p $SERVER_PASS"
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# 1. Generate Key on PRIMARY
echo ""
echo "[1/4] Generating SSH key on PRIMARY server ($PRIMARY_IP)..."
$SSHPASS_CMD ssh $SSH_OPTS $SSH_USER@$PRIMARY_IP "if [ ! -f ~/.ssh/id_ed25519 ]; then ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519; fi"
echo "Key generation ensured."

# 2. Get the Public Key
PUBKEY=$($SSHPASS_CMD ssh $SSH_OPTS $SSH_USER@$PRIMARY_IP "cat ~/.ssh/id_ed25519.pub")
if [ -z "$PUBKEY" ]; then
    echo "Error: Could not retrieve public key from PRIMARY server"
    exit 1
fi
echo "Retrieved Public Key"

# 2.5 Authorize PRIMARY (Self-Access)
echo ""
echo "[2/4] Authorizing PRIMARY to access itself..."
$SSHPASS_CMD ssh $SSH_OPTS $SSH_USER@$PRIMARY_IP "mkdir -p ~/.ssh && grep -qF '$PUBKEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added to PRIMARY'"

# 3. Install on BACKUP
echo ""
echo "[3/4] Configuring BACKUP server ($BACKUP_IP)..."
$SSHPASS_CMD ssh $SSH_OPTS $SSH_USER@$BACKUP_IP "mkdir -p ~/.ssh && grep -qF '$PUBKEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added' && sudo iptables -F 2>/dev/null && echo 'Firewall flushed' || echo 'Firewall flush skipped'"

# 4. Install on LOAD BALANCER (if configured)
if [ -n "$LB_IP" ]; then
    echo ""
    echo "[4/4] Configuring LOAD BALANCER ($LB_IP)..."
    $SSHPASS_CMD ssh $SSH_OPTS $SSH_USER@$LB_IP "mkdir -p ~/.ssh && grep -qF '$PUBKEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added' && sudo iptables -F 2>/dev/null && echo 'Firewall flushed' || echo 'Firewall flush skipped'"
else
    echo ""
    echo "[4/4] Skipping LOAD BALANCER (not configured)"
fi

echo ""
echo "=========================================="
echo "  BOOTSTRAP COMPLETE"
echo "=========================================="
echo "PRIMARY server should now be able to connect to all other servers."
echo ""
echo "Next steps:"
echo "1. SSH into PRIMARY server: ssh $SSH_USER@$PRIMARY_IP"
echo "2. Clone the repository: git clone <repo-url>"
echo "3. Configure: cp config/config.env.example config/config.env"
echo "4. Run Ansible setup: cd ansible && bash SETUP.sh"
