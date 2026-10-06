#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Uninstalling 03_log_guard ==="
unregister_pm2_root "log-guard"
rm -f /usr/local/bin/log-guard.sh
log_success "log-guard removed."