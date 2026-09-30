#!/bin/bash
set -e

echo "=== Provisioning Chrony NTP Time Synchronization ==="

# 1. Install chrony if missing
if ! command -v chronyd >/dev/null 2>&1; then
  echo "Installing chrony via APT..."
  apt-get update
  apt-get install -y chrony
else
  echo "chrony is already installed."
fi

# 2. Write optimized NTP configuration
mkdir -p /etc/chrony
cat << 'EOF' > /etc/chrony/chrony.conf
# Cloudflare & Google NTP servers
server time.cloudflare.com iburst
server time.google.com iburst

# Step system clock immediately if skew > 1.0 second
makestep 1.0 3

# Drift tracking file
driftfile /var/lib/chrony/chrony.drift

# Keep hardware clock in sync
rtcsync
EOF

mkdir -p /var/lib/chrony

# 3. Supervise under Root PM2
echo "Registering chronyd under Root PM2..."
pm2 delete chrony 2>/dev/null || true
pm2 start /usr/sbin/chronyd --name "chrony" \
  --output /dev/shm/chrony.log \
  --error /dev/shm/chrony.err \
  -- -d

pm2 save

echo "=== Chrony provisioning complete ==="