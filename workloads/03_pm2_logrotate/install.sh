#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Configuring PM2 Logrotate (RAM Protection) ==="

# 1. Configure for Root PM2
pm2 install pm2-logrotate 2>/dev/null || true
pm2 set pm2-logrotate:max_size 5M
pm2 set pm2-logrotate:retain 3
pm2 set pm2-logrotate:compress false

# 2. Configure for User (oppo) PM2
su - oppo -c "pm2 install pm2-logrotate 2>/dev/null || true"
su - oppo -c "pm2 set pm2-logrotate:max_size 5M"
su - oppo -c "pm2 set pm2-logrotate:retain 3"
su - oppo -c "pm2 set pm2-logrotate:compress false"

log_success "PM2 logrotate configured (5MB cap, 3 retentions)."