# Default parameters
$DEVICE_IP = "192.168.1.35"
$ADB_PORT = "5555"

# Load local config.env if present
$ConfigFile = Join-Path $PSScriptRoot "..\config.env"
if (Test-Path $ConfigFile) {
  Get-Content $ConfigFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)\s*=\s*"?([^"#]*)"?') {
      $k = $matches[1].Trim()
      $v = $matches[2].Trim()
      if ($k -eq "DEVICE_IP") { $DEVICE_IP = $v }
      if ($k -eq "ADB_PORT") { $ADB_PORT = $v }
    }
  }
}

$TARGET = "${DEVICE_IP}:${ADB_PORT}"

Write-Host ">>> Pushing Hardened Host Platform Scripts to $TARGET..." -ForegroundColor Cyan

# 1. Push scripts to staging
adb -s $TARGET push host/bin/chroot-debian.sh /data/local/tmp/chroot-debian.sh
adb -s $TARGET push host/service.d/00_server_init.sh /data/local/tmp/00_server_init.sh

# 2. Ensure directories exist, sanitize CRLF line endings, and install
@'
mkdir -p /data/local/bin /data/adb/service.d

sed -i 's/\r$//' /data/local/tmp/chroot-debian.sh
sed -i 's/\r$//' /data/local/tmp/00_server_init.sh

mv /data/local/tmp/chroot-debian.sh /data/local/bin/chroot-debian.sh
chmod 755 /data/local/bin/chroot-debian.sh

mv /data/local/tmp/00_server_init.sh /data/adb/service.d/00_server_init.sh
chmod 755 /data/adb/service.d/00_server_init.sh

rm -f /data/adb/service.d/00_platform_init.sh
rm -f /data/adb/service.d/01_chroot_init.sh

ls -la /data/local/bin/chroot-debian.sh
'@ | adb -s $TARGET shell su

Write-Host ">>> Host platform scripts successfully updated." -ForegroundColor Green