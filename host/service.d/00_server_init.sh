#!/system/bin/sh
# Wait for Android framework completion
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done

# 1. Defeat Android sleep, timeouts, and aggressive power restrictions
settings put global oppo_developer_options_auto_close 0 2>/dev/null || true
settings put global development_settings_enabled 1 2>/dev/null || true
settings put global wifi_sleep_policy 2 2>/dev/null || true
settings put global wifi_wakeup_available 1 2>/dev/null || true
settings put global low_power 0 2>/dev/null || true
svc power stayon true 2>/dev/null || true
dumpsys deviceidle disable 2>/dev/null || true

# 2. Kernel deep-sleep & radio latency locks
echo off > /sys/power/autosleep 2>/dev/null || true
echo "droid-server" > /sys/power/wake_lock 2>/dev/null || true
iw dev wlan0 set power_save off 2>/dev/null || true

# 3. Lock Wireless ADB to Port 5555
setprop persist.adb.tcp.port 5555
setprop service.adb.tcp.port 5555
stop adbd
start adbd

# 4. Wait for Wi-Fi association and an IPv4 address on wlan0 (up to 90s for post-blackout router boot)
IFACE="wlan0"
TIMEOUT=90
while [ $TIMEOUT -gt 0 ]; do
  if ip -4 addr show dev "$IFACE" 2>/dev/null | grep -q "inet "; then
    break
  fi
  sleep 1
  TIMEOUT=$((TIMEOUT - 1))
done

# 5. Lock default gateway in the 'main' routing table
# Scans all routing tables to capture Android netd's interface-specific gateway
GATEWAY=$(ip route show table all 2>/dev/null | grep "default via" | grep "$IFACE" | head -n 1 | awk '{print $3}')
[ -z "$GATEWAY" ] && GATEWAY=$(getprop dhcp.${IFACE}.gateway)
[ -z "$GATEWAY" ] && GATEWAY="192.168.1.1"

if [ -n "$GATEWAY" ]; then
  ip route replace default via "$GATEWAY" dev "$IFACE" table main 2>/dev/null || true
  ip rule add from all lookup main pref 30000 2>/dev/null || true
fi

# 6. Launch container platform daemons
/data/local/bin/chroot-debian.sh "/usr/sbin/sshd"
/data/local/bin/chroot-debian.sh "pm2 resurrect"

# Dynamically resolve non-root container username from sudoers
SERVER_USER=$(grep -h -r "NOPASSWD" /data/local/debian/etc/sudoers.d/ 2>/dev/null | head -n 1 | awk '{print $1}')
[ -z "$SERVER_USER" ] && SERVER_USER="oppo"
/data/local/bin/chroot-debian.sh "su - $SERVER_USER -c 'pm2 resurrect'"

# 7. Settle network tunnels
sleep 15

# 8. Surgical Headless Kill-Switch: Reclaim ~3.5 GB RAM while preserving netd and adbd
setprop ctl.stop zygote
setprop ctl.stop zygote_secondary
setprop ctl.stop surfaceflinger
setprop ctl.stop audioserver