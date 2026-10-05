# Oppo A91 (CPH2021) Headless Debian Server

> Repurposing a shattered-display Oppo A91 smartphone into an ultra-low-power, 24/7 headless ARM64 Linux home server running native Debian 12 (Bookworm) via an unvirtualized Linux mount namespace (chroot) powered by a custom DC-regulated battery emulator.

---

## Hardware & Architecture Baseline

| Subsystem | Specification | Notes |
| :--- | :--- | :--- |
| **SoC** | MediaTek Helio P70 (`MT6771V/CT`) | Octa-core: 4× Cortex-A73 @ 2.11 GHz + 4× Cortex-A53 @ 2.0 GHz |
| **Memory** | 8 GB LPDDR4X | ~6.5 GB liberated for userland via surgical `ctl.stop zygote` |
| **Storage** | 128 GB UFS 2.1 | All volatile logs/caches pinned to RAM tmpfs to eliminate flash wear |
| **Power Stack** | 9V PD/QC -> XL4015 Buck (4.00V DC) | Desoldered OEM BMS tabs; zero pouch-cell swelling risk |
| **Host OS** | ColorOS 11 (Android 11) | Kernel `4.14.186+` with Magisk Root v30.7 |
| **Userland** | Debian 12 (Bookworm) ARM64 | 9 canonical mounts (`proc`, `sys`, `dev`, `shm`, `run`, `tmp`, etc.) |
| **Networking** | Static DHCP (`192.168.1.35`) | Tailscale WireGuard mesh overlay + remote keyless SSH |

---

## Quick Navigation & Documentation

Full architectural runbooks, triage guides, and schematics are maintained in the local Docsify portal:

* **[Master Platform Invariants](docs/00_PLATFORM/README.md):** The 4-tier invariant stack governing hardware, kernel, container, and runtimes.
* **[Hardware & Power Runbook](docs/00_PLATFORM/Hardware_Power.md):** XL4015 calibration, BMS sleep-lockout recovery, PMIC latching, and chassis grounding.
* **[Host Recovery & Magisk](docs/00_PLATFORM/Host_Recovery.md):** MTK BootROM (BROM) unbricking, `service.d` boot sequencing, and wireless ADB hardening.
* **[Container Engine](docs/00_PLATFORM/Chroot_Engine.md):** Mount namespace management (`chroot-debian.sh`), SUID flags, and OpenSSH access.
* **[Service Catalog](docs/01_SERVICES/README.md):** Registry of PM2-supervised daemons (Tailscale, Docsify, Chrony, Network Watchdog).

---

## Workstation Operations (VS Code / PowerShell)

All deployment and maintenance tasks are automated via VS Code tasks (`Ctrl+Shift+B`) or PowerShell scripts in `./workstation/`:

```powershell
# Run universal hardware and container health probe:
powershell -ExecutionPolicy Bypass -File ./workstation/healthcheck.ps1

# Deploy updated host scripts (chroot launcher, init pipeline):
powershell -ExecutionPolicy Bypass -File ./workstation/push_host_scripts.ps1

# Deploy container userland configuration and dotfiles:
powershell -ExecutionPolicy Bypass -File ./workstation/push_container.ps1

# Sync documentation portal (viewable at http://192.168.1.35:8080):
powershell -ExecutionPolicy Bypass -File ./workstation/sync_docs.ps1
```

---

## Primary Access Endpoints

* **Local SSH:** `ssh oppo@192.168.1.35` (Port `22`, passwordless `sudo`)
* **Tailscale SSH:** `ssh oppo@oppo-server` (Keyless out-of-band mesh)
* **Wireless ADB:** `adb connect 192.168.1.35:5555`
* **Documentation Portal:** `http://192.168.1.35:8080` (or `http://oppo-server:8080`)