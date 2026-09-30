#!/system/bin/sh
# Wait for Android framework completion
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done

# 1. Defeat ColorOS sleep, timeouts, and power restrictions
settings put global oppo_developer_options_auto_close 0
settings put global development_settings_enabled 1
settings put global wifi_sleep_policy 2
settings put global wifi_wakeup_available 1
settings put global low_power 0
svc power stayon true
dumpsys deviceidle disable

# 2. Kernel deep-sleep & radio latency locks
echo off > /sys/power/autosleep
echo "oppo-server" > /sys/power/wake_lock
iw dev wlan0 set power_save off 2>/dev/null || true

# 3. Lock Wireless ADB to Port 5555
setprop persist.adb.tcp.port 5555
setprop service.adb.tcp.port 5555
stop adbd
start adbd

# 4. Wait for Wi-Fi association and an IPv4 address on wlan0 (up to 90s for post-blackout router boot)
TIMEOUT=90
while [ $TIMEOUT -gt 0 ]; do
  if ip -4 addr show dev wlan0 | grep -q "inet "; then
    break
  fi
  sleep 1
  TIMEOUT=$((TIMEOUT - 1))
done

# 5. Lock default gateway in the 'main' routing table
# Android moves default routes to private tables; this ensures standard Linux processes can route egress traffic.
GATEWAY=$(ip route show dev wlan0 | grep default | awk '{print $3}')
[ -z "$GATEWAY" ] && GATEWAY="192.168.1.1"
ip route add default via "$GATEWAY" dev wlan0 table main 2>/dev/null || true
ip rule add from all lookup main pref 30000 2>/dev/null || true

# 6. Launch container platform daemons
/data/local/bin/chroot-debian.sh "/usr/sbin/sshd"
/data/local/bin/chroot-debian.sh "pm2 resurrect"
/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 resurrect'"

# 7. Settle network tunnels
sleep 15

# 8. Surgical Headless Kill-Switch: Reclaim ~3.5 GB RAM without terminating netd
setprop ctl.stop zygote
setprop ctl.stop zygote_secondary
setprop ctl.stop surfaceflinger
setprop ctl.stop audioserver