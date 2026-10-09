# Brief / Meta (Master System Manifest & Navigation Protocol)

> **Role:** Global parameters, architecture baseline, system directory, and master health check.  
> **Context Ingestion Rule:** Paste this tab first when initializing an engineering session to orient the model on hardware, network endpoints, and execution paths.

---

### SYSTEM MANIFEST

| Component | Specification |
| :--- | :--- |
| **Target Machine** | Oppo A91 (`CPH2021`) \| MediaTek Helio P70 (`MT6771V`) \| 8GB LPDDR4X \| 128GB UFS 2.1 |
| **Host OS** | ColorOS 11 (Android 11) \| Magisk Root v30.7 \| Linux Kernel `4.14.186+` |
| **Container Runtime** | Debian 12 (Bookworm) ARM64 Native Chroot (9 Canonical Mounts) |
| **Installed Runtimes** | Python 3.11.2 (PEP 668 / venv) \| Node.js 24 LTS (`v24.x` / `npm 11.x`) \| PM2 Daemon Supervisor |
| **Resilience Daemons** | Self-healing L3 Network Watchdog \| Chrony NTP Timesync \| POSIX Log Guard |
| **Mesh Remote Access** | Tailscale WireGuard Overlay (`100.x.y.z`) \| Tailscale SSH (`oppo@oppo-server`) |
| **Flash Endurance** | Ephemeral caches, runtime sockets, and compile scratchpads on tmpfs (`/dev/shm`, `/run`, `/tmp`) |
| **Physical State** | Headless (Display Dead) \| DC Regulated Dummy Battery (3.93V - 4.00V DC) |
| **Primary Endpoint** | `192.168.1.35` (Static DHCP Reservation) \| Hostname: `oppo` |
| **Primary SSH Access** | `oppo@192.168.1.35:22` (Passwordless `sudo`) \| Fallback: `root@192.168.1.35:22` |

---

## 1. DOCUMENT TAXONOMY & DIRECTORY

This documentation uses a decoupled, three-tier architecture. Adding or modifying application modules under `01_SERVICES` requires zero edits to parent platform tabs.

```text
DroidServer/
├── Brief / Meta            <── (YOU ARE HERE) Global parameters, taxonomy, dynamic health
│
├── 00_PLATFORM             <── INVARIANTS: Hardware, Android host, BROM unbrick, chroot engine
│   ├── Hardware_Power      <── 4.00V calibration, BMS sleep-jump, PMIC latching, grounding
│   ├── Host_Recovery       <── Magisk service.d, wireless ADB (5555), MTKClient raw restore
│   ├── Chroot_Engine       <── Mount namespace script, suid userdata, OpenSSH, surgical ctl.stop
│   └── Runtime_Essentials  <── Node 24 LTS, Python 3.11, PM2 supervisor, UFS tmpfs caching
│
├── 01_SERVICES             <── WORKLOAD CONTRACTS & CORE INFRASTRUCTURE
│   ├── _TEMPLATE           <── Master contract: blueprint for modular workloads
│   ├── Docs_Portal         <── Single Docsify portal (:8080) with dynamic workload overlay
│   ├── Tailscale           <── Zero-trust mesh VPN overlay & passwordless SSH
│   └── Playwright          <── Anti-pattern case study: browser workload ban
│
└── hardware                <── DEVICE CASE STUDIES & HARDWARE SPECIFICS
    └── oppo_a91            <── 4.00V calibration, BMS sleep-jump, MTK BROM unbricking
```

---

## 2. UNIVERSAL MASTER HEALTH CHECK

Execute from your workstation terminal via `Ctrl+Shift+B` in VS Code or run:

**`[Workstation:PS>]`**
```powershell
powershell -ExecutionPolicy Bypass -File ./workstation/healthcheck.ps1
```

### Healthy Output Baseline

| Subsystem | Expected Metric | Diagnostic Implication |
| :--- | :--- | :--- |
| **Rail Voltage** | `3930` – `4000` mV | XL4015 buck operating within PMIC stable UVLO/OVP bounds |
| **Available Memory** | `> 6,500 MB` Available | Android UI dead; RAM reclaimed for container (~1.5–1.8 GB used) |
| **Zygote Status** | Empty or `stopped` | SurfaceFlinger and display compositors halted |
| **Netd Status** | `running` | Native Linux network manager preserved; DNS and routing tables intact |
| **Active Mounts** | Exactly `9 of 9` | `proc`, `sys`, `dev`, `dev/pts`, `dev/shm`, `run`, `tmp`, `mnt/adb`, `mnt/host-bin` |
| **Listening Ports** | Ports `5555`, `22`, `8080` + Daemons | Host ADB (:5555), Debian SSH (:22), Docsify (:8080) |

---

## 3. GLOBAL OPERATOR RULES OF ENGAGEMENT

### Target Execution Environments

* **`[Workstation:PS>]`** — PowerShell 7+ on the Windows management workstation.  
* **`[Workstation:Arch-Fish❯]`** — Fish shell on Arch Linux (Laptop / Workstation via Kitty).  
* **`[Host:Android#]`** — Elevated root shell on Android host OS (`adb -s 192.168.1.35:5555 shell su`).  
* **`[Debian:oppo$]`** — Primary userland interactive shell (`ssh oppo@192.168.1.35` or `ssh oppo@oppo-server`).  
* **`[Debian:root#]`** — Elevated container root shell (`ssh root@192.168.1.35` or `/data/local/bin/chroot-debian.sh`).

### Core Platform Constraints

* **The Silicon No-Reboot Invariant (Cold-Powerkey Latch):**  
  **NEVER** issue host-level reboots (`reboot`, `reboot -f`, `echo b > /proc/sysrq-trigger`). On this MT6771 + MT6358 architecture with a dummy battery and no active USB V_BUS, software reboots collapse PMIC rails to 0V and latch into an unrecoverable shutdown state requiring physical `PWRKEY` ground assertion (`cold,powerkey`). Always restart the Debian container userland (`pkill -u oppo && /data/local/bin/chroot-debian.sh /usr/sbin/sshd`), never the silicon host.  
    
* **Host Maintenance Backdoor Boundary:**  
  Android host files are bind-mounted at `/mnt/adb` and `/mnt/host-bin` for emergency interactive maintenance via `sudo nano` or `sudo micro`. These paths are **frozen platform invariants**. Daily application workloads must be managed via PM2 inside Debian userland rather than editing host boot scripts.  
    
* **The Backfeed Protection Rule:**  
  **NEVER** plug the PC USB cable into the phone if the 18W buck converter input is unpowered. Input voltage to the XL4015 must be active (`V_IN ≥ 9.0V`) before connecting a PC data cable to prevent reverse current from flowing through the converter's internal body diode.  
    
* **The Headless Constraint:**  
  The display panel is 100% non-functional. Never issue commands or trigger prompts that halt waiting for physical on-screen touch verification. Android GUI automation (`uiautomator`) and headless browsers (`chromium`, `puppeteer`) are strictly prohibited.  
    
* **Hardware Grounding Integrity:**  
  The single chassis screw located directly above the coin vibration motor (L2b A76) must remain torqued down to ground the volume rocker flex pads to the motherboard logic circuits for MTK BROM capture.  
    
* **Kernel Autosleep Invariant:**  
  Opportunistic kernel sleep is permanently locked off (`echo off > /sys/power/autosleep` and `echo oppo-server > /sys/power/wake_lock`) to guarantee 24/7 unthrottled CPU ticks.  
    
* **Flash Wear Mitigation Rule:**  
  Soldered UFS 2.1 flash must be protected from high-frequency writes. All package caches (`pip`, `npm`), intermediate bytecode (`.pycache`), runtime sockets, and volatile logs must be pinned to RAM tmpfs buffers (`/dev/shm`, `/run`, `/tmp`).