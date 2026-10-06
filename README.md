# Oppo A91 (CPH2021) Headless Debian Server

[![Debian 12](https://img.shields.io/badge/Userland-Debian_12_(Bookworm)-A80056?style=flat-square&logo=debian&logoColor=white)](https://www.debian.org/)
[![Kernel](https://img.shields.io/badge/Kernel-4.14.186+-333333?style=flat-square&logo=linux&logoColor=white)](https://kernel.org/)
[![Arch](https://img.shields.io/badge/Arch-ARM64_%2F_aarch64-0091BD?style=flat-square&logo=arm&logoColor=white)](https://arm.com)
[![Power](https://img.shields.io/badge/Power-4.00V_DC_Regulated-FFA000?style=flat-square&logo=adafruit&logoColor=white)](docs/00_PLATFORM/Hardware_Power.md)
[![Root](https://img.shields.io/badge/Root-Magisk_v30.7-00B0FF?style=flat-square)](https://github.com/topjohnwu/Magisk)
[![Mesh](https://img.shields.io/badge/Mesh-Tailscale-000000?style=flat-square&logo=tailscale&logoColor=white)](https://tailscale.com)
[![Supervisor](https://img.shields.io/badge/Supervisor-PM2-2B037A?style=flat-square&logo=pm2&logoColor=white)](https://pm2.keymetrics.io/)

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

# Deploy modular workloads (00_base, 01_net_watchdog, etc.):
powershell -ExecutionPolicy Bypass -File ./workstation/deploy_workload.ps1

# Sync platform documentation portal (viewable at http://192.168.1.35:8080):
powershell -ExecutionPolicy Bypass -File ./workstation/sync_docs.ps1

# Compile and sync application registry (viewable at http://192.168.1.35:8081):
powershell -ExecutionPolicy Bypass -File ./workstation/sync_app_docs.ps1
```

---

## Primary Access Endpoints

* **Local SSH:** `ssh oppo@192.168.1.35` (Port `22`, passwordless `sudo`)
* **Tailscale SSH:** `ssh oppo@oppo-server` (Keyless out-of-band mesh)
* **Wireless ADB:** `adb connect 192.168.1.35:5555`
* **Platform Docs Portal (Public):** `http://192.168.1.35:8080` (or `http://oppo-server:8080`)
* **Workload App Registry (Private LAN):** `http://192.168.1.35:8081` (or `http://oppo-server:8081`)
* **Documentation Portal (Out-of-Band):** `https://grrgrrman.github.io/OppoA91/`

---

## Upstream Toolchain & Prior Art

This server's unbricked, unlocked, and persistent execution state is built upon the foundational work of the following projects:

| Project / Tool | Role in Architecture | Reference |
| :--- | :--- | :--- |
| **`oppo-mtk-fastboot-unlock`** | MediaTek BROM SLA/DA handshake authentication bypass to unlock the bootloader on MT6771 ColorOS devices. | [![GitHub](https://img.shields.io/badge/GitHub-Shocked--Cat%2Foppo--mtk--fastboot--unlock-181717?style=flat-square&logo=github)](https://github.com/Shocked-Cat/oppo-mtk-fastboot-unlock) |
| **`mtkclient`** | Low-level BootROM manipulation, partition dumping, empty `vbmeta` deployment, and raw partition recovery. | [![GitHub](https://img.shields.io/badge/GitHub-bkerler%2Fmtkclient-181717?style=flat-square&logo=github)](https://github.com/bkerler/mtkclient) |
| **`Magisk`** | Root privilege manager, sepolicy database configuration, and late-start `service.d` platform init engine. | [![GitHub](https://img.shields.io/badge/GitHub-topjohnwu%2FMagisk-181717?style=flat-square&logo=github)](https://github.com/topjohnwu/Magisk) |
| **`Docsify`** | Client-side, zero-build Markdown documentation engine served via unprivileged local HTTP. | [![GitHub](https://img.shields.io/badge/GitHub-docsifyjs%2Fdocsify-181717?style=flat-square&logo=github)](https://github.com/docsifyjs/docsify) |
| **`fastfetch`** | Lightweight, dependency-free system telemetry CLI deployed strictly to RAM tmpfs. | [![GitHub](https://img.shields.io/badge/GitHub-fastfetch--cli%2Ffastfetch-181717?style=flat-square&logo=github)](https://github.com/fastfetch-cli/fastfetch) |