# DroidServer: Universal Headless Android Linux Server Framework

[![Debian 12](https://img.shields.io/badge/Userland-Debian_12_(Bookworm)-A80056?style=flat-square&logo=debian&logoColor=white)](https://www.debian.org/)
[![Kernel](https://img.shields.io/badge/Kernel-Linux_ARM64-333333?style=flat-square&logo=linux&logoColor=white)](https://kernel.org/)
[![Architecture](https://img.shields.io/badge/Arch-AArch64-0091BD?style=flat-square&logo=arm&logoColor=white)](https://arm.com)
[![Virtualization](https://img.shields.io/badge/Overhead-0%25_(Native_Chroot)-brightgreen?style=flat-square)]()
[![Flash Protection](https://img.shields.io/badge/Storage-RAM_tmpfs_Protected-orange?style=flat-square)]()
[![Process Supervisor](https://img.shields.io/badge/Supervisor-PM2-2B037A?style=flat-square&logo=pm2&logoColor=white)](https://pm2.keymetrics.io/)
[![Mesh Network](https://img.shields.io/badge/Overlay-Tailscale-000000?style=flat-square&logo=tailscale&logoColor=white)](https://tailscale.com)

> Transform recycled, display-shattered, or retired Android smartphones into high-efficiency, 24/7 headless ARM64 Linux servers running native Debian 12 (Bookworm) with **0% virtualization loss** and **zero flash wear**.

---

## Architectural Highlights

* **Native Mount Namespace (Chroot):** Runs directly on the Android Linux kernel with unvirtualized bare-metal performance, bypassing PRoot/VM emulation penalties.
* **Surgical RAM Liberation:** Selectively halts display compositors and the Android Java framework (`ctl.stop zygote`, `ctl.stop surfaceflinger`) while keeping `netd` alive, freeing **3.0 GB to 4.5 GB of RAM** for Linux userland.
* **Flash Endurance Layer (RAM tmpfs):** Eliminates write wear on soldered UFS/eMMC NAND flash. High-frequency package caches (`pip`, `npm`), runtime bytecode (`.pycache`), volatile sockets, and daemon logs are routed exclusively to RAM tmpfs (`/dev/shm`, `/run`, `/tmp`).
* **Hardware Abstraction (Two-Tier Power):** Supports software charge limiting (capping retained batteries at 60%–70% via sysfs/ACC) as well as hardware battery emulation (DC buck regulated conversion).
* **Virtual IPMI Console (Wireless ADB):** Out-of-band management remains reachable via Wireless ADB on port `5555` even if container OpenSSH services freeze.

---

## Reference Hardware Baseline (Oppo A91 Build)

| Subsystem | Specification | Notes |
| :--- | :--- | :--- |
| **SoC** | MediaTek Helio P70 (`MT6771V`) | Octa-core: 4× Cortex-A73 @ 2.11 GHz + 4× Cortex-A53 @ 2.0 GHz |
| **Memory** | 8 GB LPDDR4X | **~6.6 GB liberated** for userland via surgical init control |
| **Storage** | 128 GB UFS 2.1 | All volatile logs/caches pinned to RAM tmpfs |
| **Power Stack** | 9V PD/QC -> XL4015 Buck (4.00V DC) | Desoldered OEM BMS tabs; zero pouch-cell swelling risk |
| **Host OS** | ColorOS 11 (Android 11) | Kernel `4.14.186+` with Magisk Root |
| **Container** | Debian 12 (Bookworm) ARM64 | 9 canonical mounts (`proc`, `sys`, `dev`, `shm`, `run`, `tmp`, etc.) |
| **Mesh Access** | Tailscale WireGuard Overlay | Out-of-band passwordless SSH access |

---

## Quick Navigation & Documentation

* **[Platform Architecture](docs/00_PLATFORM/README.md):** The core invariant stack governing host Android and container runtimes.
* **[Power & Thermals](docs/00_PLATFORM/Hardware_Power.md):** Software battery limiting vs. physical dummy battery regulation.
* **[Oppo A91 Hardware Case Study](docs/hardware/oppo_a91.md):** Complete hardware conversion runbook (XL4015 calibration, BMS tweezer jump, MTK BROM unbricking).
* **[Chroot Engine](docs/00_PLATFORM/Chroot_Engine.md):** Mount namespace management, SUID flags, and OpenSSH configuration.
* **[Service Catalog](docs/01_SERVICES/README.md):** PM2-supervised daemons (Tailscale, Chrony NTP, Network Watchdog, Docsify).

---

## Workstation Operations (VS Code / PowerShell)

All deployment and maintenance tasks are automated via VS Code tasks (`Ctrl+Shift+B`) or PowerShell scripts in `./workstation/`:

```powershell
# Copy config template and configure local target IP:
Copy-Item ./config.env.example ./config.env

# Universal hardware and container health probe:
powershell -ExecutionPolicy Bypass -File ./workstation/healthcheck.ps1

# Deploy updated host scripts (chroot launcher, init pipeline):
powershell -ExecutionPolicy Bypass -File ./workstation/push_host_scripts.ps1

# Deploy container userland configuration and dotfiles:
powershell -ExecutionPolicy Bypass -File ./workstation/push_container.ps1

# Deploy modular workloads (00_base, 01_net_watchdog, chrony, etc.):
powershell -ExecutionPolicy Bypass -File ./workstation/deploy_workload.ps1

# Sync documentation portal with dynamic workload overlay:
powershell -ExecutionPolicy Bypass -File ./workstation/sync_docs.ps1
```

---

## Primary Endpoints

* **Local SSH:** `ssh oppo@<device-ip>` (Port `22`, passwordless `sudo`)
* **Tailscale SSH:** `ssh oppo@oppo-server` (Keyless out-of-band mesh)
* **Wireless ADB:** `adb connect <device-ip>:5555`
* **Documentation Portal:** `http://<device-ip>:8080` (Consolidated single-port portal)
* **Out-of-Band Docs:** `https://grrgrrman.github.io/OppoA91/`