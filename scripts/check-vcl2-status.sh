#!/usr/bin/env bash
# Quick script to check VCL2 app status

echo "=== Checking VCL2 Application Status ==="
echo ""

VCL2_HOST="152.7.178.106"

echo "1. Testing root endpoint:"
curl -v http://$VCL2_HOST:3000/ 2>&1 | grep -E "(< HTTP|Connection|curl:)"
echo ""

echo "2. Testing /coffees endpoint:"
curl -s http://$VCL2_HOST:3000/coffees | head -n 5
echo ""

echo "3. Container status (requires SSH):"
echo "   SSH into VCL2 and run: docker ps"
echo ""

echo "4. Check recent logs (requires SSH):"
echo "   SSH into VCL2 and run: sudo docker logs coffee_app --tail=20"

