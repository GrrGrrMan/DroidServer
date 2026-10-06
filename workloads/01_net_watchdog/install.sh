#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Installing 01_net_watchdog ==="

mkdir -p /usr/local/bin
cp "$DIR/bin/network-watchdog.sh" /usr/local/bin/network-watchdog.sh
chmod 755 /usr/local/bin/network-watchdog.sh

register_pm2_root "net-watchdog" "/usr/local/bin/network-watchdog.sh"