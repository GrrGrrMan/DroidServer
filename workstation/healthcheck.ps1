$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null
$TARGET = "192.168.1.35:5555"

Write-Host ">>> Querying Hardware & Container Telemetry on $TARGET..." -ForegroundColor Cyan

@'
# Hardware & Container Telemetry Probe
echo "================================================================="
echo " 1. HARDWARE PMIC & VOLTAGE RAIL TELEMETRY"
echo "================================================================="
# Voltage: normalize microvolts vs millivolts
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
cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 4 | awk '{printf "%s°C ", $1/1000}'
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
echo " 4. CONTAINER MOUNT HIERARCHY (EXPECT EXACTLY 9)"
echo "================================================================="
MOUNTS=$(mount | grep "/data/local/debian")
COUNT=$(echo "$MOUNTS" | grep -v '^$' | wc -l)
echo "Active Mount Count: $COUNT of 9"
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
echo "--- User (oppo) PM2 Supervised Daemons ---"
/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 list'" 2>/dev/null || echo "User PM2 daemon inactive"
'@ | adb -s $TARGET shell su