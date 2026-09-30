#!/bin/bash
set -e

echo "=== Provisioning Self-Healing Network Watchdog ==="

# 1. Ensure binary directory exists and install watchdog
mkdir -p /usr/local/bin
if [ -f /tmp/provision/network-watchdog.sh ]; then
  cp /tmp/provision/network-watchdog.sh /usr/local/bin/network-watchdog.sh
fi
chmod 755 /usr/local/bin/network-watchdog.sh

# 2. Register and start under Root PM2
echo "Registering network watchdog under Root PM2..."
pm2 delete net-watchdog 2>/dev/null || true
pm2 start /usr/local/bin/network-watchdog.sh --name "net-watchdog" \
  --output /dev/shm/net-watchdog.log \
  --error /dev/shm/net-watchdog.err

pm2 save

echo "=== Network Watchdog provisioning complete ==="