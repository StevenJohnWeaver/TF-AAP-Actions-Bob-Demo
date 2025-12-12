#!/bin/bash
# Quick script to fix stuck AAP jobs
# Run this on your AAP controller when jobs are stuck

set -e

echo "========================================="
echo "AAP Stuck Job Recovery Script"
echo "========================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo or as root"
    exit 1
fi

echo "1. Checking AAP services status..."
systemctl status automation-controller --no-pager | head -10
echo ""

echo "2. Checking for stuck jobs..."
sudo -u awx awx-manage list_instances
echo ""

echo "3. Cleaning up stuck jobs..."
sudo -u awx awx-manage cleanup_jobs --days=0
echo "✅ Stuck jobs cleared"
echo ""

echo "4. Restarting AAP services..."
systemctl restart automation-controller
echo "⏳ Waiting for services to start..."
sleep 10
echo ""

echo "5. Verifying services are running..."
if systemctl is-active --quiet automation-controller; then
    echo "✅ automation-controller is running"
else
    echo "❌ automation-controller failed to start"
    echo "Check logs: sudo journalctl -u automation-controller -n 50"
    exit 1
fi

if systemctl is-active --quiet receptor; then
    echo "✅ receptor is running"
else
    echo "⚠️  receptor is not running (may be normal for some setups)"
fi

echo ""
echo "========================================="
echo "✅ Recovery Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Go to AAP UI and sync your project"
echo "2. Relaunch the job"
echo ""
echo "If issues persist, check:"
echo "  - sudo journalctl -u automation-controller -f"
echo "  - /var/log/tower/dispatcher.log"
echo "  - System resources: free -h && df -h"

# Made with Bob
