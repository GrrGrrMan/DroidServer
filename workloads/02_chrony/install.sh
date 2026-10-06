#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Installing 02_chrony NTP Timesync ==="

if ! command -v chronyd >/dev/null 2>&1; then
  log_info "Installing chrony via APT..."
  apt-get update
  apt-get install -y --no-install-recommends chrony
  apt-get clean
  rm -rf /var/lib/apt/lists/*
fi

mkdir -p /etc/chrony /var/lib/chrony
cp "$DIR/etc/chrony.conf" /etc/chrony/chrony.conf

register_pm2_root "chrony" "/usr/sbin/chronyd" -d