#!/bin/bash
# Complete Automated Infrastructure Setup Script
# This script handles everything from scratch to production-ready infrastructure
#
# For NCSU Students:
#   1. Update ansible/inventory.yml with your VCL IPs and username
#   2. Update ansible/inventory-password.yml with your VCL IPs and username
#   3. Run this script from VCL2 (control node)
#
# Usage: bash SETUP.sh

set -e  # Exit on error

echo "==========================================="
echo "  DEVOPS PROJECT - INFRASTRUCTURE SETUP"
echo "==========================================="
echo ""
echo "This will setup:"
echo "  - VCL1: Load Balancer (Nginx)"
echo "  - VCL2: Primary Application Server"
echo "  - VCL3: Standby Server with Failover"
echo ""

# Check if we're in the right directory
if [ ! -f "inventory.yml" ] || [ ! -f "inventory-password.yml" ]; then
    echo "ERROR: inventory.yml or inventory-password.yml not found!"
    echo "Please run this script from the ansible/ directory"
    exit 1
fi

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    sudo apt-get update -qq
    sudo apt-get install -y sshpass
fi

echo ""
echo "Step 1/3: Fixing connectivity issues on all VCLs..."
echo "This will clear iptables and firewalls to ensure Ansible can connect."
echo ""
read -sp "Enter your VCL password: " VCL_PASSWORD
echo ""

# Fix connectivity using password authentication
if ansible-playbook -i inventory-password.yml 0-fix-connectivity.yml \
    --extra-vars "ansible_password=$VCL_PASSWORD ansible_become_password=$VCL_PASSWORD" \
    -e "ansible_ssh_pass=$VCL_PASSWORD" \
    -e "ansible_become_pass=$VCL_PASSWORD"; then
    echo "✓ Connectivity fixed on all VCLs"
else
    echo "WARNING: Some connectivity fixes may have failed. Continuing anyway..."
fi

echo ""
echo "Step 2/3: Setting up SSH keys for passwordless authentication..."
echo ""

# Setup SSH keys using password authentication
if ansible-playbook -i inventory-password.yml 0-initial-setup.yml \
    --extra-vars "ansible_password=$VCL_PASSWORD ansible_become_password=$VCL_PASSWORD" \
    -e "ansible_ssh_pass=$VCL_PASSWORD" \
    -e "ansible_become_pass=$VCL_PASSWORD"; then
    echo "✓ SSH keys setup successfully"
else
    echo "ERROR: SSH key setup failed!"
    exit 1
fi

# Clear password from memory
VCL_PASSWORD=""

echo ""
echo "Step 3/3: Deploying complete infrastructure..."
echo "This will take 15-20 minutes. Using passwordless SSH authentication."
echo ""

# Run the complete infrastructure setup using SSH keys
if ansible-playbook -i inventory.yml site.yml; then
    echo ""
    echo "==========================================="
    echo "  ✓ SETUP COMPLETE!"
    echo "==========================================="
    echo ""
    echo "Your infrastructure is ready to use!"
    echo ""
else
    echo ""
    echo "==========================================="
    echo "  ⚠ SETUP INCOMPLETE"
    echo "==========================================="
    echo ""
    echo "Some steps may have failed. Check the output above."
    echo "You can manually run: ansible-playbook -i inventory.yml site.yml"
    echo ""
    exit 1
fi
