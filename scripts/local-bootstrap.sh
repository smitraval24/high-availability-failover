#!/bin/bash
# scripts/local-bootstrap.sh
# Run this from your LOCAL machine (Laptop/Desktop)
# This script bridges the connectivity gap between VCL nodes.

# Configuration - UPDATE THESE IF NEEDED
USER="sraval"
VCL1_IP="152.7.176.221"
VCL2_IP="152.7.177.180"
VCL3_IP="152.7.178.104"

echo "=========================================="
echo "  VCL CONNECTIVITY BOOTSTRAP"
echo "=========================================="
echo "This script will:"
echo "1. Generate an SSH key on VCL2 (Control Node)"
echo "2. Copy that key to VCL1 and VCL3"
echo "3. Flush firewalls on VCL1 and VCL3"
echo ""
echo "You will be asked for your VCL password ONCE (if sshpass is installed)."
echo "=========================================="

# Check for sshpass
if ! command -v sshpass &> /dev/null; then
    echo "⚠️  WARNING: 'sshpass' is not installed on this machine."
    echo "   You will still need to enter your password manually."
    echo "   (To fix this: install sshpass via your package manager)"
    SSHPASS_CMD=""
else
    read -sp "Enter your VCL password: " VCL_PASS
    echo ""
    SSHPASS_CMD="sshpass -p $VCL_PASS"
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# 1. Generate Key on VCL2
echo ""
echo "[1/3] Generating SSH key on VCL2..."
# Check if key exists first to avoid overwrite prompt, or generate if missing
$SSHPASS_CMD ssh $SSH_OPTS $USER@$VCL2_IP "if [ ! -f ~/.ssh/id_ed25519 ]; then ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519; fi"
echo "✓ Key generation ensured."

# 2. Get the Public Key
PUBKEY=$($SSHPASS_CMD ssh $SSH_OPTS $USER@$VCL2_IP "cat ~/.ssh/id_ed25519.pub")
if [ -z "$PUBKEY" ]; then
    echo "Error: Could not retrieve public key from VCL2"
    exit 1
fi
echo "✓ Retrieved Public Key"

# 2.5 Authorize VCL2 (Self-Access)
echo ""
echo "[1.5/3] Authorizing VCL2 to access itself..."
$SSHPASS_CMD ssh $SSH_OPTS $USER@$VCL2_IP "mkdir -p ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo '✓ Key added to VCL2'"

# 3. Install on VCL1
echo ""
echo "[2/3] Configuring VCL1 ($VCL1_IP)..."
$SSHPASS_CMD ssh $SSH_OPTS $USER@$VCL1_IP "mkdir -p ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo '✓ Key added' && sudo iptables -F && echo '✓ Firewall flushed'"

# 4. Install on VCL3
echo ""
echo "[3/3] Configuring VCL3 ($VCL3_IP)..."
$SSHPASS_CMD ssh $SSH_OPTS $USER@$VCL3_IP "mkdir -p ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo '✓ Key added' && sudo iptables -F && echo '✓ Firewall flushed'"

echo ""
echo "=========================================="
echo "  BOOTSTRAP COMPLETE"
echo "=========================================="
echo "VCL2 should now be able to connect to VCL1 and VCL3."
echo "You can now SSH into VCL2 and run 'bash SETUP.sh'"
