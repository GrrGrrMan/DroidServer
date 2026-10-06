#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Uninstalling 02_chrony ==="
unregister_pm2_root "chrony"
uninstall_pkg "chrony"
rm -rf /etc/chrony /var/lib/chrony
log_success "chrony removed."