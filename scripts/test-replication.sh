#!/usr/bin/env bash
# test-replication.sh - Test replication with full error output
set -euo pipefail

REMOTE_USER=vpatel29
REMOTE_HOST=152.7.178.91

echo "=== Testing Database Replication ==="
echo ""

# Test 1: Can we connect to VCL3?
echo "1. Testing SSH connection to VCL3..."
if ssh -o ConnectTimeout=5 "${REMOTE_USER}@${REMOTE_HOST}" "echo 'Connected!'" 2>&1; then
    echo "   ✓ SSH connection works"
else
    echo "   ✗ SSH connection failed"
    exit 1
fi
echo ""

# Test 2: Is docker-compose available on VCL3?
echo "2. Testing docker-compose on VCL3..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose ps" 2>&1
echo ""

# Test 3: Can we execute psql commands?
echo "3. Testing database commands on VCL3..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres -c 'SELECT version();'" 2>&1
echo ""

# Test 4: Try to create coffee_dev database
echo "4. Creating coffee_dev database on VCL3..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres -c 'DROP DATABASE IF EXISTS coffee_dev;'" 2>&1
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres -c 'CREATE DATABASE coffee_dev;'" 2>&1
echo ""

# Test 5: Verify database was created
echo "5. Verifying coffee_dev database exists..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/devops-project/coffee_project && sudo docker-compose exec -T db psql -U postgres -c '\l' | grep coffee_dev" 2>&1
echo ""

echo "=== All tests passed! ==="

