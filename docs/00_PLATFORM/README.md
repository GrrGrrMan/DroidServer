# 00_PLATFORM (Master Platform Invariants & Architecture)

> **Role:** Parent management dashboard for the four-tier infrastructure foundation: physical DC power regulation, MediaTek BROM/bootloader recovery, native Debian mount namespaces, and core language runtime engines.  
> **Blast Radius:** **CRITICAL (PLATFORM-WIDE)**. Failures at this layer result in hardware thermal shutdown, Little Kernel bootloops, loss of root authority, or catastrophic container filesystem unmounts.

---

## 1. THE FOUR-TIER INVARIANT STACK

The platform is constructed as a decoupled four-layer infrastructure foundation. Modifications to higher layers (such as userland services in `01_SERVICES`) must never violate the electrical, kernel, or permission invariants of lower platform tiers:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ Layer 3: RUNTIME ENGINES (00_PLATFORM/Runtime_Essentials)              │
│ - Node.js 24 LTS | Python 3.11.2 (PEP 668) | PM2 Process Supervisor    │
│ - Ephemeral RAM tmpfs caching (/dev/shm) protecting UFS 2.1 storage    │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 2: CONTAINER RUNTIME (00_PLATFORM/Chroot_Engine)                 │
│ - Debian 12 Bookworm ARM64 Chroot (0% PRoot Virtualization Loss)       │
│ - 7 Active Mounts: proc, sys, dev, dev/pts, dev/shm, mnt/adb, host-bin │
│ - Headless 'stop' Memory Reclaim (>6,800 MB LPDDR4X Liberated)         │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 1: HOST OS & RECOVERY (00_PLATFORM/Host_Recovery)                │
│ - ColorOS 11 (Android 11) | Magisk Root v30.7 | Linux Kernel 4.14.186+ │
│ - Wireless ADB (:5555) locked open via service.d | MTK BROM Unbrick    │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 0: ELECTRICAL & PHYSICAL (00_PLATFORM/Hardware_Power)            │
│ - XL4015 DC Regulated Rail (4.00V) -> Desoldered OEM BMS tabs          │
│ - Chassis Screw Torqued (Volume Ground) | MT6358 PMIC Cold-Powerkey    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. MASTER PLATFORM TELEMETRY & HARDWARE PROBES

Execute these diagnostic one-liners from your workstation (over ADB) or inside an elevated shell to query the physical power state, memory allocation, and kernel device tree:

### A. Query PMIC Voltage, Thermal Zones, and CPU Governor

**`[Workstation:PS>]`**
```powershell
adb -s 192.168.1.35:5555 shell "su -c '
  echo \"--- PMIC Battery Rail ---\";
  dumpsys battery | grep -E \"voltage|level|status\";
  echo \"--- SoC Thermal Sensors ---\";
  cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 4 | awk \"{print \$1/1000 \\\"°C\\\"}\";
  echo \"--- Kernel Autosleep State ---\";
  cat /sys/power/autosleep;
'"
```

### B. Verify Container Memory Allocation and Headless UI State

**`[Workstation:PS>]`**
```powershell
adb -s 192.168.1.35:5555 shell "su -c '
  echo \"--- Memory State (Expect >6,800 MB Available) ---\";
  free -m;
  echo -n \"Zygote Service: \"; getprop init.svc.zygote;
  echo -n \"SurfaceFlinger: \"; getprop init.svc.surfaceflinger;
'"
```

### C. Verify Active Namespace Mounts (Expect Exactly 7)

**`[Workstation:PS>]`**
```powershell
adb -s 192.168.1.35:5555 shell "su -c 'mount | grep \"/data/local/debian\" | awk \"{print \$3}\"'"
```

---

## 3. NON-NEGOTIABLE PLATFORM INVARIANTS

| Parameter | Operational Boundary | Failure Consequence if Violated |
| :--- | :--- | :--- |
| **Rail Voltage (`V_BAT`)** | **3.95V – 4.00V DC** | `<3.40V` triggers MT6358 PMIC UVLO brownout; `>4.35V` trips BMS OVP latch. |
| **Backfeed Protection** | **`V_IN >= 9.0V` before PC USB** | Reverse current forward-biases XL4015 internal body diode, risking board destruction. |
| **Silicon Reboot Rule** | **NEVER issue host reboot** | Without USB `V_BUS`, warm resets drop PMIC rails to 0V and latch into hard shutdown (`cold,powerkey`). |
| **Headless Integrity** | **OLED 100% shattered** | Android GUI tools (`uiautomator`) waste 3.5 GB RAM and crash on unresolvable slider captchas. |
| **Socket Permissions** | **Android GID 3003 (`aid_inet`)** | Non-root users (`oppo`) fail with `Permission denied` on all network socket calls. |
| **Flash Wear Limit** | **Volatile logs/caches in `/dev/shm`** | High-frequency package manager writes degrade soldered, non-replaceable UFS 2.1 NAND cells. |
| **Maintenance Mounts** | **`/mnt/adb` and `/mnt/host-bin` frozen** | Accidental edits to host scripts break container autostart on subsequent boots. |

---

## 4. PLATFORM CHILD TAB DIRECTORY

To inspect or modify specific low-level subsystems, navigate to the dedicated child tabs:

1. **[00_PLATFORM/Hardware_Power](Hardware_Power.md)**  
   *Scope:* XL4015 calibration, BMS sleep-lockout recovery jumpering, passive heatsink convective chimney design, and mechanical chassis grounding.  
2. **[00_PLATFORM/Host_Recovery](Host_Recovery.md)**  
   *Scope:* MTK Helio P70 BootROM unbricking via `mtkclient`, Magisk root database SQLite policy injection, multi-workstation `adb_keys` pairing, and ColorOS sleep defeat.  
3. **[00_PLATFORM/Chroot_Engine](Chroot_Engine.md)**  
   *Scope:* Master mount namespace script (`chroot-debian.sh`), 7 virtual filesystem bindings, SUID enforcement, OpenSSH setup, and the `stop` memory reclaim mechanism.  
4. **[00_PLATFORM/Runtime_Essentials](Runtime_Essentials.md)**  
   *Scope:* Pre-compiled Node.js 24 LTS and Python 3.11 runtimes, PEP 668 virtualenv standards, PM2 supervisor configuration, and UFS flash RAM caching.