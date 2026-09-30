#!/system/bin/sh
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 3
done

# 1. Defeat ColorOS Sleep & Timeouts
settings put global oppo_developer_options_auto_close 0
settings put global development_settings_enabled 1
settings put global wifi_sleep_policy 2
settings put global wifi_wakeup_available 1
settings put global low_power 0
svc power stayon true
dumpsys deviceidle disable

# 2. Kernel Deep-Sleep & Latency Locks
echo off > /sys/power/autosleep
echo "oppo-server" > /sys/power/wake_lock
iw dev wlan0 set power_save off 2>/dev/null || true

# 3. Lock Wireless ADB Daemon to Port 5555
setprop persist.adb.tcp.port 5555
setprop service.adb.tcp.port 5555
stop adbd
start adbd
