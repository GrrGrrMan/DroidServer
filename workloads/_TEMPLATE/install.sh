#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Installing MODULE_NAME ==="
# 1. Install packages or download binaries to /tmp (RAM tmpfs)
# 2. Copy configs from $DIR/config/ to /etc/MODULE_NAME/
# 3. Register with PM2 via register_pm2_root or register_pm2_user
