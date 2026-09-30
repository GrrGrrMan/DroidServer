#!/bin/bash
set -e

echo "=== Provisioning Fastfetch CLI (UFS Flash Protection) ==="

if ! command -v fastfetch >/dev/null 2>&1; then
  echo "Installing fastfetch from upstream ARM64 release..."
  # Download strictly to /tmp (RAM tmpfs) to eliminate flash wear
  curl -sL https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-aarch64.deb -o /tmp/fastfetch.deb
  apt-get install -y /tmp/fastfetch.deb
  rm -f /tmp/fastfetch.deb
  echo "fastfetch installed successfully."
else
  echo "fastfetch is already installed."
fi

echo "=== Fastfetch provisioning complete ==="