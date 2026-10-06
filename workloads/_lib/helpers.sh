#!/bin/bash
# workloads/_lib/helpers.sh - Flash-Safe Common Provisioning Helpers

set -e

# Colored logging helpers
log_info()    { echo -e "\033[0;34m[INFO]\033[0m  $*"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
log_warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
log_err()     { echo -e "\033[0;31m[ERR]\033[0m   $*"; }

# 1. Flash-Safe APT Batch Installer
install_apt_manifest() {
  local manifest="$1"
  if [ ! -f "$manifest" ]; then
    log_err "Manifest file not found: $manifest"
    return 1
  fi

  local pkgs
  pkgs=$(grep -vE '^\s*(#|$)' "$manifest" | tr '\n' ' ')
  if [ -z "$pkgs" ]; then
    log_warn "No packages found in $manifest"
    return 0
  fi

  local missing=""
  for pkg in $pkgs; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing="$missing $pkg"
    fi
  done

  if [ -n "$missing" ]; then
    log_info "Installing missing packages:$missing"
    apt-get update
    apt-get install -y --no-install-recommends $missing
    # UFS Flash Protection: Eliminate cached .deb archives immediately
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    log_success "Packages successfully installed:$missing"
  else
    log_success "All packages in $(basename "$manifest") are already installed."
  fi
}

# 2. APT Batch Uninstaller (Reversible Teardown)
uninstall_apt_manifest() {
  local manifest="$1"
  if [ ! -f "$manifest" ]; then
    log_err "Manifest file not found: $manifest"
    return 1
  fi

  local pkgs
  pkgs=$(grep -vE '^\s*(#|$)' "$manifest" | tr '\n' ' ')
  local to_remove=""
  for pkg in $pkgs; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      to_remove="$to_remove $pkg"
    fi
  done

  if [ -n "$to_remove" ]; then
    log_info "Purging packages:$to_remove"
    apt-get purge -y $to_remove
    apt-get autoremove -y
    apt-get clean
    log_success "Packages purged:$to_remove"
  else
    log_info "None of the packages in $(basename "$manifest") are installed."
  fi
}

# 3. Flash-Safe Remote .deb Installer (Pinned strictly to RAM tmpfs)
install_deb_url() {
  local bin_name="$1"
  local url="$2"
  local pkg_name="${3:-$bin_name}"

  if command -v "$bin_name" >/dev/null 2>&1 || dpkg -s "$pkg_name" >/dev/null 2>&1; then
    log_success "$bin_name is already installed."
    return 0
  fi

  log_info "Downloading $bin_name to RAM tmpfs (/tmp)..."
  local tmp_deb="/tmp/${bin_name}.deb"
  curl -sL "$url" -o "$tmp_deb"

  log_info "Installing $bin_name via APT..."
  apt-get install -y "$tmp_deb"
  rm -f "$tmp_deb"
  log_success "$bin_name installed successfully."
}

# 4. Single Package Purge Helper
uninstall_pkg() {
  local pkg_name="$1"
  if dpkg -s "$pkg_name" >/dev/null 2>&1; then
    log_info "Purging package: $pkg_name"
    apt-get purge -y "$pkg_name"
    apt-get autoremove -y
    apt-get clean
    log_success "Package $pkg_name purged."
  else
    log_info "$pkg_name is not installed."
  fi
}

# 5. Root PM2 Registration (Routes volatile logs strictly to RAM /dev/shm)
register_pm2_root() {
  local name="$1"
  local script_path="$2"
  shift 2

  log_info "Registering Root PM2 daemon: $name"
  pm2 delete "$name" 2>/dev/null || true
  if [ $# -gt 0 ]; then
    pm2 start "$script_path" --name "$name" \
      --output "/dev/shm/${name}.log" \
      --error "/dev/shm/${name}.err" \
      -- "$@"
  else
    pm2 start "$script_path" --name "$name" \
      --output "/dev/shm/${name}.log" \
      --error "/dev/shm/${name}.err"
  fi
  pm2 save
  log_success "PM2 daemon $name registered and state saved."
}

# 6. Root PM2 Teardown Helper
unregister_pm2_root() {
  local name="$1"
  log_info "Unregistering Root PM2 daemon: $name"
  pm2 delete "$name" 2>/dev/null || true
  pm2 save
  rm -f "/dev/shm/${name}.log" "/dev/shm/${name}.err"
  log_success "PM2 daemon $name removed."
}