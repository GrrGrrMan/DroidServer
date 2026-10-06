#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Installing 03_log_guard (RAM tmpfs Protection) ==="

mkdir -p /usr/local/bin
cp "$DIR/bin/log-guard.sh" /usr/local/bin/log-guard.sh
chmod 755 /usr/local/bin/log-guard.sh

register_pm2_root "log-guard" "/usr/local/bin/log-guard.sh"