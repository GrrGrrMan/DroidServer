# Host_Recovery (Sub-Tab: 00_PLATFORM)

> **Scope:** Bootloader recovery, low-level MTK BROM unbricking, persistent Magisk root configuration, ColorOS 11 background daemon defeat, unified boot orchestration, and permanent network ADB provisioning.  
> **Blast Radius:** **CRITICAL**. Errors here cause bootloops, loss of root authority, or permanent loss of remote headless communication.

---

## 1. HARDWARE-LEVEL DISASTER RECOVERY (MTK BROM)

If the Android OS fails to boot, enters a Red State loop, or becomes corrupt, the MediaTek MT6771 BootROM (BROM) provides raw hardware-level partition access independent of the installed OS.

### BROM Handshake Protocol

1. Ensure the 18W power delivery stack is active and supplying **3.95V – 4.00V DC** to the BMS board.  
2. Verify that the chassis screw above the vibration motor is torqued down (grounding the volume flex pads).  
3. Connect the 4-wire USB data cable to the workstation PC.  
4. Press and hold **Volume Up + Volume Down** simultaneously.  
5. In terminal, execute:

**`[Workstation:PS>]`**
```powershell
python mtk printgpt
```

*If GPT partitions print, the silicon BROM bus is captured.*

### Emergency Partition Restore Matrix

**`[Workstation:PS>]`**
```powershell
# Restore Stock Boot (Unroot)
python mtk w boot boot.img

# Flash Magisk Rooted Kernel
python mtk w boot magisk_patched.img

# Disable Android Verified Boot (AVB / dm-verity)
python mtk w vbmeta vbmeta.img.empty

# Wipe Corrupted Userdata & Cache
python mtk e metadata,userdata,md_udc

# Restore OEM Security Config
python mtk w seccfg seccfg.bin

# Hardware Reset / Normal Boot
python mtk reset
```

---

## 2. MAGISK HEADLESS ROOT HARDENING

On a headless machine with no functional display, Magisk must never block waiting for on-screen user authorization.

### Database Policy Injection

Run inside an elevated shell (`adb shell su`) to permanently grant root to UID 2000 (`shell`) and configure global auto-grant:

**`[Host:Android#]`**
```bash
magisk --sqlite "INSERT OR REPLACE INTO settings (key,value) VALUES ('su_auto_response',1);"
magisk --sqlite "INSERT OR REPLACE INTO settings (key,value) VALUES ('su_access',3);"
magisk --sqlite "INSERT OR REPLACE INTO settings (key,value) VALUES ('su_notification',0);"
magisk --sqlite "INSERT OR REPLACE INTO policies (uid,policy,until,logging,notification) VALUES (2000,2,0,0,0);"
```

---

## 3. PERMANENT WORKSTATION RSA AUTHORIZATION (adb_keys)

Prevent ColorOS from revoking ADB debugging access or prompting for host verification:

**`[Workstation:PS>]`**
```powershell
# From Windows PowerShell:
adb push "$($env:USERPROFILE)\.android\adbkey.pub" /data/local/tmp/workstation_key.pub

# Append to system trusted keystore and set permissions:
adb shell "su -c '
  cat /data/local/tmp/workstation_key.pub >> /data/misc/adb/adb_keys
  chown system:shell /data/misc/adb/adb_keys
  chmod 640 /data/misc/adb/adb_keys
  rm /data/local/tmp/workstation_key.pub
'"
```

---

## 4. UNIFIED PLATFORM INITIALIZER (service.d)

ColorOS 11 automatically disables Developer Options after 10 minutes and suspends Wi-Fi radios when the screen is off. Magisk's late-start init engine executes this unified script on cold boot to orchestrate the entire boot pipeline, eliminate race conditions, pin network routes, and execute surgical headless RAM reclaim:

* **File Path:** `/data/adb/service.d/00_server_init.sh`  
* **File Mode:** `755` (`-rwxr-xr-x`)

**`[Host:Android#]`**
```bash
#!/system/bin/sh
# Wait until Android framework is fully initialized
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done

# 1. Defeat ColorOS Sleep & Developer Timeouts
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

# 4. Wait for Wi-Fi association and an IPv4 address on wlan0 (up to 90s for post-blackout router boot)
TIMEOUT=90
while [ $TIMEOUT -gt 0 ]; do
  if ip -4 addr show dev wlan0 | grep -q "inet "; then
    break
  fi
  sleep 1
  TIMEOUT=$((TIMEOUT - 1))
done

# 5. Lock default gateway in routing table 'main'
GATEWAY=$(ip route show dev wlan0 | grep default | awk '{print $3}')
[ -z "$GATEWAY" ] && GATEWAY="192.168.1.1"
ip route add default via "$GATEWAY" dev wlan0 table main 2>/dev/null || true
ip rule add from all lookup main pref 30000 2>/dev/null || true

# 6. Launch container daemons
/data/local/bin/chroot-debian.sh "/usr/sbin/sshd"
/data/local/bin/chroot-debian.sh "pm2 resurrect"
/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 resurrect'"

# 7. Settle network tunnels
sleep 15

# 8. Surgical Headless Kill-Switch: Reclaim ~3.5 GB RAM while preserving netd
setprop ctl.stop zygote
setprop ctl.stop zygote_secondary
setprop ctl.stop surfaceflinger
setprop ctl.stop audioserver
```

---

## 5. SYSTEM INFORMATION & HARDWARE TELEMETRY (FASTFETCH)

For fast terminal system diagnostics without `systemd` or desktop dependencies, upstream `fastfetch` is used.

### Installation Standard (Flash Wear Protection)
Because Debian 12 Bookworm does not include `fastfetch` in its core repository, the upstream ARM64 release is staged strictly in RAM `tmpfs` (`/tmp`) before installation to prevent UFS flash wear:

```bash
curl -sL https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-aarch64.deb -o /tmp/fastfetch.deb
sudo apt install -y /tmp/fastfetch.deb
rm -f /tmp/fastfetch.deb
```

---

## 6. TRIAGE & FAILURE MODES

| Symptom | Probable Root Cause | Resolution Protocol |
| :--- | :--- | :--- |
| **Wireless ADB connection refused (`:5555`)** | Wi-Fi radio entered sleep state or `adbd` failed to bind to port. | Verify DHCP reservation. If IP is active, connect USB cable (buck powered first), run `adb devices`, and verify property `getprop service.adb.tcp.port`. |
| **Device enters 5-second rhythmic USB disconnect loop** | Little Kernel AVB verification panic (Red State). | Hold Vol+ and Vol- to catch BROM with `mtkclient`. Reflash `vbmeta.img.empty` and verify `boot.img` integrity. |
| **ADB shell hangs indefinitely when invoking `su`** | Magisk database policy reverted or `su_auto_response` was reset to prompt. | Re-execute the SQLite policy injection block in Section 2 to force UID 2000 auto-grant. |
| **Host CPU pinned at 100% by `app_process` / `magiskd` workers** | Magisk attempting to dispatch Toast notifications / su logs to Android's `ActivityManager`, which is dead after `ctl.stop zygote`. | Set `logging=0`, `notification=0`, and `su_notification=0` in Magisk SQLite policy. Terminate child `magiskd` workers while preserving master daemon PID 583. |
| **Detached background jobs stack up on host** | Background processes (`&`) spawned over ADB without stdout/stderr redirection (`>/dev/null 2>&1 &`) leave remote sessions alive after client disconnect. | Always manage background daemons via PM2 inside Debian userland; avoid raw `&` background tasks on the Android host. |