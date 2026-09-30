param (
  [string]$Script = ""
)

$TARGET = "192.168.1.35:5555"
$STAGE = "/data/local/tmp/provision_stage"
$CHROOT_TMP = "/data/local/debian/tmp/provision"

Write-Host ">>> Staging Provisioning Scripts to $TARGET (RAM tmpfs)..." -ForegroundColor Cyan

# 1. Stage in /data/local/tmp (writable by ADB shell user)
adb -s $TARGET shell "rm -rf $STAGE && mkdir -p $STAGE"
adb -s $TARGET push container/provision/. "$STAGE/"
if (Test-Path "container/bin") {
  adb -s $TARGET push container/bin/. "$STAGE/"
}

# 2. Elevate via root: copy into container /tmp/provision (RAM tmpfs), sanitize CRLF, and set 755
@'
STAGE="/data/local/tmp/provision_stage"
CHROOT_TMP="/data/local/debian/tmp/provision"

mkdir -p "$CHROOT_TMP"
cp -rf "$STAGE/." "$CHROOT_TMP/"
rm -rf "$STAGE"

find "$CHROOT_TMP" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null
chmod -R 755 "$CHROOT_TMP"
echo "Staged provisioning scripts successfully to $CHROOT_TMP"
'@ | adb -s $TARGET shell su

# 3. Execute provisioning script(s) inside chroot
if ($Script -ne "") {
  Write-Host ">>> Executing $Script inside Debian chroot..." -ForegroundColor Cyan
  adb -s $TARGET shell "su -c '/data/local/bin/chroot-debian.sh /tmp/provision/$Script'"
} else {
  Write-Host ">>> Executing all provisioning scripts sequentially..." -ForegroundColor Cyan
  @'
  for f in $(ls /data/local/debian/tmp/provision/*.sh | sort); do
    if echo "$f" | grep -qE "/[0-9]{2}_"; then
      BNAME=$(basename "$f")
      echo "=========================================================="
      echo " Executing: $BNAME"
      echo "=========================================================="
      /data/local/bin/chroot-debian.sh "/tmp/provision/$BNAME"
    fi
  done
'@ | adb -s $TARGET shell su
}

Write-Host ">>> Provisioning sequence finished." -ForegroundColor Green