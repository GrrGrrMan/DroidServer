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
│ - Ephemeral tmpfs caching (/dev/shm, /run, /tmp) protecting UFS 2.1    │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 2: CONTAINER RUNTIME (00_PLATFORM/Chroot_Engine)                 │
│ - Debian 12 Bookworm ARM64 Chroot (0% PRoot Virtualization Loss)       │
│ - 9 Active Mounts: proc, sys, dev, dev/pts, shm, run, tmp, adb, bin    │
│ - Surgical 'ctl.stop' Memory Reclaim (Netd preserved, ~3.5GB liberated)│
├────────────────────────────────────────────────────────────────────────┤
│ Layer 1: HOST OS & RECOVERY (00_PLATFORM/Host_Recovery)                │
│ - ColorOS 11 (Android 11) | Magisk Root v30.7 | Linux Kernel 4.14.186+ │
│ - Unified 00_server_init.sh pipeline | Table main routing lock         │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 0: ELECTRICAL & PHYSICAL (00_PLATFORM/Hardware_Power)            │
│ - XL4015 DC Regulated Rail (3.93V - 4.00V) -> Desoldered OEM BMS tabs   │
│ - Chassis Screw Torqued (Volume Ground) | MT6358 PMIC Cold-Powerkey    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. HARDWARE & KERNEL SYSFS TELEMETRY

Execute the master healthcheck from your workstation terminal or via VS Code (`Ctrl+Shift+B`):

**`[Workstation:PS>]`**
```powershell
powershell -ExecutionPolicy Bypass -File ./workstation/healthcheck.ps1
```

### Telemetry Baseline

| Subsystem | Target Metric | Safe Bounds / Implication |
| :--- | :--- | :--- |
| **Rail Voltage** | `3930` – `4000` mV | XL4015 buck operating above PMIC UVLO (3400 mV) and below OVP (4350 mV) |
| **Battery Status** | `Not charging` | Normal for OEM BMS dummy battery with unpopulated thermistor lines |
| **SoC Thermals** | `25°C` – `50°C` | Cool idle under passive heatsinks; values of `-127°C` are unpopulated channels |
| **Container Mounts** | Exactly `9 of 9` | `proc`, `sys`, `dev`, `dev/pts`, `dev/shm`, `run`, `tmp`, `mnt/adb`, `mnt/host-bin` |
| **Active Gateway** | Pinned in `table main` | Pinned default route via active subnet gateway preventing network isolation |
| **Netd Status** | `running` | Native Linux network manager preserved; DNS and routing tables intact |

---

## 3. NON-NEGOTIABLE PLATFORM INVARIANTS

| Parameter | Operational Boundary | Failure Consequence if Violated |
| :--- | :--- | :--- |
| **Rail Voltage (`V_BAT`)** | **3.95V – 4.00V DC** | `<3.40V` triggers MT6358 PMIC UVLO brownout; `>4.35V` trips BMS OVP latch. |
| **Backfeed Protection** | **`V_IN >= 9.0V` before PC USB** | Reverse current forward-biases XL4015 internal body diode, risking board destruction. |
| **Silicon Reboot Rule** | **NEVER issue host reboot** | Without USB `V_BUS`, warm resets drop PMIC rails to 0V and latch into hard shutdown (`cold,powerkey`). |
| **Headless Integrity** | **OLED 100% shattered** | Android GUI tools (`uiautomator`) waste 3.5 GB RAM and crash on unresolvable slider captchas. |
| **Socket Permissions** | **Android GID 3003 (`aid_inet`)** | Non-root users (`oppo`) fail with `Permission denied` on all network socket calls. |
| **Flash Wear Limit** | **RAM tmpfs buffers** | Ephemeral caches, runtime sockets, and compile trees must live in `/dev/shm`, `/run`, and `/tmp`. |
| **Maintenance Mounts** | **`/mnt/adb` and `/mnt/host-bin` frozen** | Accidental edits to host scripts break container autostart on subsequent boots. |
| **Mount Check Guard** | **Parse `/proc/mounts`** | Toybox `mountpoint -q` fails on same-filesystem bind mounts, creating runaway mount leaks. |

---

## 4. PLATFORM CHILD TAB DIRECTORY

To inspect or modify specific low-level subsystems, navigate to the dedicated child tabs:

1. **[00_PLATFORM/Hardware_Power](Hardware_Power.md)**  
   *Scope:* XL4015 calibration, BMS sleep-lockout recovery jumpering, passive heatsink convective chimney design, and mechanical chassis grounding.  
2. **[00_PLATFORM/Host_Recovery](Host_Recovery.md)**  
   *Scope:* MTK Helio P70 BootROM unbricking via `mtkclient`, Magisk root database SQLite policy injection, multi-workstation `adb_keys` pairing, and unified `00_server_init.sh` boot orchestration.  
3. **[00_PLATFORM/Chroot_Engine](Chroot_Engine.md)**  
   *Scope:* Master mount namespace script (`chroot-debian.sh`), 9 virtual filesystem bindings, SUID enforcement, OpenSSH setup, and surgical `ctl.stop` memory reclaim.  
4. **[00_PLATFORM/Runtime_Essentials](Runtime_Essentials.md)**  
   *Scope:* Pre-compiled Node.js 24 LTS and Python 3.11 runtimes, PEP 668 virtualenv standards, PM2 supervisor configuration, and UFS flash RAM caching.