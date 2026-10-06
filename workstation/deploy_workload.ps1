param (
  [string]$Module = "ALL",
  [ValidateSet("install", "uninstall")]
  [string]$Action = "install"
)

$TARGET = "192.168.1.35:5555"
$STAGE = "/data/local/tmp/workloads_stage"
$CHROOT_TMP = "/data/local/debian/tmp/workloads"

Write-Host ">>> Staging Workloads to $TARGET (RAM tmpfs)..." -ForegroundColor Cyan

# 1. Clean and stage in /data/local/tmp (writable by adb shell user)
adb -s $TARGET shell "rm -rf $STAGE && mkdir -p $STAGE"
adb -s $TARGET push workloads/. "$STAGE/"

# 2. Elevate via root: copy into container /tmp/workloads (RAM tmpfs), sanitize CRLF, and chmod 755
@'
STAGE="/data/local/tmp/workloads_stage"
CHROOT_TMP="/data/local/debian/tmp/workloads"

mkdir -p "$CHROOT_TMP"
cp -rf "$STAGE/." "$CHROOT_TMP/"
rm -rf "$STAGE"

find "$CHROOT_TMP" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null
chmod -R 755 "$CHROOT_TMP"
echo "Workloads staged successfully to $CHROOT_TMP (RAM tmpfs)."
'@ | adb -s $TARGET shell su

# 3. Execute requested action inside chroot
if ($Module -ne "ALL") {
  Write-Host ">>> Executing $Action on module: $Module..." -ForegroundColor Cyan
  $cmd = "MODULE='$Module'`nACTION='$Action'`n" + @'
  HOST_SCRIPT="/data/local/debian/tmp/workloads/$MODULE/$ACTION.sh"
  CHROOT_SCRIPT="/tmp/workloads/$MODULE/$ACTION.sh"
  if [ -f "$HOST_SCRIPT" ]; then
    /data/local/bin/chroot-debian.sh "$CHROOT_SCRIPT"
  else
    echo "[ERR] Target script not found: $HOST_SCRIPT"
    exit 1
  fi
'@
  $cmd | adb -s $TARGET shell su
} else {
  Write-Host ">>> Executing $Action on ALL modules sequentially..." -ForegroundColor Cyan
  $cmd = "ACTION='$Action'`n" + @'
  for mod in $(ls -d /data/local/debian/tmp/workloads/[0-9]* /data/local/debian/tmp/workloads/_local/* 2>/dev/null | sort); do
    if [ -d "$mod" ] && [ -f "$mod/$ACTION.sh" ]; then
      BNAME=$(basename "$mod")
      echo "=========================================================="
      echo " Module: $BNAME | Action: $ACTION"
      echo "=========================================================="
      CHROOT_MOD_PATH=$(echo "$mod" | sed 's|/data/local/debian||')
      /data/local/bin/chroot-debian.sh "$CHROOT_MOD_PATH/$ACTION.sh"
    fi
  done
'@
  $cmd | adb -s $TARGET shell su
}

# 4. Clean up volatile staging buffer from RAM tmpfs
@'
rm -rf /data/local/debian/tmp/workloads
echo "RAM staging buffer cleaned up."
'@ | adb -s $TARGET shell su

Write-Host ">>> Workload deployment finished ($Action -> $Module)." -ForegroundColor Green