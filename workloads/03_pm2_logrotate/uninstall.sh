#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Uninstalling PM2 Logrotate ==="
pm2 uninstall pm2-logrotate 2>/dev/null || true
su - oppo -c "pm2 uninstall pm2-logrotate 2>/dev/null || true"
log_success "PM2 logrotate uninstalled."