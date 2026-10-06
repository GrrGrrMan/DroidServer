#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Uninstalling MODULE_NAME ==="
# 1. Unregister PM2 daemon
# 2. Purge package via uninstall_pkg
# 3. Clean /etc configs and state directories
