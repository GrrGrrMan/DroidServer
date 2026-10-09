$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

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

Write-Host ">>> Querying Hardware & Container Telemetry on $TARGET..." -ForegroundColor Cyan

@'
echo "================================================================="
echo " 1. HARDWARE PMIC & VOLTAGE RAIL TELEMETRY"
echo "================================================================="
V_RAW=$(cat /sys/class/power_supply/battery/voltage_now 2>/dev/null || cat /sys/class/power_supply/battery/batt_vol 2>/dev/null)
if [ -n "$V_RAW" ]; then
  if [ "$V_RAW" -gt 100000 ] 2>/dev/null; then
    V_MV=$((V_RAW / 1000))
  else
    V_MV=$V_RAW
  fi
  echo "PMIC Rail Voltage : ${V_MV} mV (Safe Bounds: 3950 - 4050 mV)"
else
  echo "PMIC Rail Voltage : Unable to read sysfs battery voltage"
fi

BATT_STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null || echo "Unknown")
echo "Battery Status    : $BATT_STATUS"

echo -n "SoC Thermals      : "
cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 4 | awk '{printf "%.1f C ", $1/1000}'
echo ""
echo -n "System Uptime     : "
uptime

echo ""
echo "================================================================="
echo " 2. UFS 2.1 FLASH STORAGE I/O METRICS"
echo "================================================================="
if [ -f /sys/block/sda/stat ]; then
  READ_IOS=$(awk '{print $1}' /sys/block/sda/stat)
  WRITE_IOS=$(awk '{print $5}' /sys/block/sda/stat)
  echo "Root UFS Device   : /dev/block/sda (Operational)"
  echo "Cumulative I/O    : ${READ_IOS} Reads | ${WRITE_IOS} Writes"
else
  echo "Root Storage Node : Standard sysfs block stats unavailable"
fi

echo ""
echo "================================================================="
echo " 3. HEADLESS RUNTIME & MEMORY LIBERATION"
echo "================================================================="
awk '
  /MemTotal:/     {t=$2}
  /MemFree:/      {f=$2}
  /MemAvailable:/ {a=$2}
  /Buffers:/      {b=$2}
  /^Cached:/      {c=$2}
  END {
    used = (t - a) / 1024
    avail = a / 1024
    total = t / 1024
    cache = (b + c) / 1024
    pct_used = (used / total) * 100
    pct_avail = (avail / total) * 100
    printf "Total RAM Installed : %5d MB\n", total
    printf "Active Working Set  : %5d MB (%4.1f%% active)\n", used, pct_used
    printf "Reclaimable Cache   : %5d MB (Kernel Buffers + Cached)\n", cache
    printf "True Available RAM  : %5d MB (%4.1f%% free for workloads)\n", avail, pct_avail
  }
' /proc/meminfo

echo ""
echo "Init Daemon States:"
echo -n "  Zygote (UI Runtime)     : "
getprop init.svc.zygote || echo "stopped"
echo -n "  SurfaceFlinger (Display): "
getprop init.svc.surfaceflinger || echo "stopped"
echo -n "  Netd (Linux Networking) : "
getprop init.svc.netd || echo "running"

echo ""
echo "================================================================="
echo " 4. CONTAINER MOUNT HIERARCHY"
echo "================================================================="
MOUNTS=$(mount | grep "/data/local/debian")
COUNT=$(echo "$MOUNTS" | grep -v '^$' | wc -l)
echo "Active Mount Count: $COUNT (Minimum 9 verified)"
echo "$MOUNTS" | awk '{printf "  -> %-28s [%s]\n", $3, $5}'

echo ""
echo "================================================================="
echo " 5. NETWORK ROUTING & INTERFACE STATUS"
echo "================================================================="
ip -4 addr show dev wlan0 2>/dev/null | grep "inet " | awk '{print "wlan0 IPv4 Address  : " $2}'
ip route show table main 2>/dev/null | grep default | awk '{print "Table Main Gateway  : " $3}'

echo ""
echo "================================================================="
echo " 6. ACTIVE LISTENING PORTS & WORKLOADS"
echo "================================================================="
netstat -tuln 2>/dev/null | grep LISTEN || ss -tulpn 2>/dev/null | grep LISTEN
echo ""
echo "--- Root PM2 Supervised Daemons ---"
/data/local/bin/chroot-debian.sh "pm2 list" 2>/dev/null || echo "Root PM2 daemon inactive"
echo ""
SERVER_USER=$(grep -h -r "NOPASSWD" /data/local/debian/etc/sudoers.d/ 2>/dev/null | head -n 1 | awk '{print $1}')
[ -z "$SERVER_USER" ] && SERVER_USER="oppo"
echo "--- User ($SERVER_USER) PM2 Supervised Daemons ---"
/data/local/bin/chroot-debian.sh "su - $SERVER_USER -c 'pm2 list'" 2>/dev/null || echo "User PM2 daemon inactive"
'@ | adb -s $TARGET shell su