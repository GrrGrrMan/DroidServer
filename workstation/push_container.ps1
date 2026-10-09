# Default parameters
$DEVICE_IP = "192.168.1.35"
$ADB_PORT = "5555"
$SERVER_USER = "oppo"

# Load local config.env if present
$ConfigFile = Join-Path $PSScriptRoot "..\config.env"
if (Test-Path $ConfigFile) {
  Get-Content $ConfigFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)\s*=\s*"?([^"#]*)"?') {
      $k = $matches[1].Trim()
      $v = $matches[2].Trim()
      if ($k -eq "DEVICE_IP") { $DEVICE_IP = $v }
      if ($k -eq "ADB_PORT") { $ADB_PORT = $v }
      if ($k -eq "SERVER_USER") { $SERVER_USER = $v }
    }
  }
}

$TARGET = "${DEVICE_IP}:${ADB_PORT}"
Write-Host ">>> Pushing Container Configuration Files to $TARGET..." -ForegroundColor Cyan

# 1. Stage container directory to /data/local/tmp/container_stage
adb -s $TARGET shell "rm -rf /data/local/tmp/container_stage && mkdir -p /data/local/tmp/container_stage"
adb -s $TARGET push container/. /data/local/tmp/container_stage/

# 2. Elevate via root, sanitize CRLF, and copy into /data/local/debian/
@'
CHROOT="/data/local/debian"
STAGE="/data/local/tmp/container_stage"

# Sanitize CRLF line endings on all staged shell/config files
find "$STAGE" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null

# Sync bin/
if [ -d "$STAGE/bin" ]; then
  mkdir -p "$CHROOT/usr/local/bin"
  cp -rf "$STAGE/bin/." "$CHROOT/usr/local/bin/"
  chmod -R 755 "$CHROOT/usr/local/bin"
fi

# Sync etc/
if [ -d "$STAGE/etc" ]; then
  cp -rf "$STAGE/etc/." "$CHROOT/etc/"
fi

# Sync home dotfiles for any user directories defined in container/home/
if [ -d "$STAGE/home" ]; then
  for udir in "$STAGE/home"/*; do
    if [ -d "$udir" ]; then
      uname=$(basename "$udir")
      mkdir -p "$CHROOT/home/$uname"
      cp -rf "$udir/." "$CHROOT/home/$uname/"
      chown -R 1000:1000 "$CHROOT/home/$uname"
    fi
  done
fi

# Sync pm2/ (ecosystem process configurations)
if [ -d "$STAGE/pm2" ]; then
  mkdir -p "$CHROOT/etc/pm2"
  cp -rf "$STAGE/pm2/." "$CHROOT/etc/pm2/"
  chown -R 1000:1000 "$CHROOT/etc/pm2"
fi

# Clean up temporary stage buffer
rm -rf "$STAGE"
echo "Container files deployed successfully."
'@ | adb -s $TARGET shell su

Write-Host ">>> Container deployment complete." -ForegroundColor Green