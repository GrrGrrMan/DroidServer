$TARGET = "192.168.1.35:5555"
Write-Host ">>> Pushing Container Configuration Files to $TARGET..." -ForegroundColor Cyan

# 1. Stage container directory to /data/local/tmp/container_stage (writable by ADB shell user)
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

# Sync home/oppo/ (copies dotfiles like .bashrc and .npmrc)
if [ -d "$STAGE/home/oppo" ]; then
  cp -rf "$STAGE/home/oppo/." "$CHROOT/home/oppo/"
  chown -R 1000:1000 "$CHROOT/home/oppo"
fi

# Clean up temporary stage buffer
rm -rf "$STAGE"
echo "Container files deployed successfully."
'@ | adb -s $TARGET shell su

Write-Host ">>> Container deployment complete." -ForegroundColor Green