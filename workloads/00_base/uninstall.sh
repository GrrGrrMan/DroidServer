#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_lib/helpers.sh"

log_info "=== Removing 00_base system packages ==="
uninstall_apt_manifest "$DIR/packages.apt"