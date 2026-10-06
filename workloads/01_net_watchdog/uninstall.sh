#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Uninstalling 01_net_watchdog ==="
unregister_pm2_root "net-watchdog"
rm -f /usr/local/bin/network-watchdog.sh
log_success "net-watchdog binary and PM2 process removed."