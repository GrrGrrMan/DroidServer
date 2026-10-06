# Fastfetch CLI (`04_fastfetch`)

> **Role:** High-speed system telemetry and hardware inspection CLI.  
> **Lifecycle:** Upstream pre-compiled ARM64 deb package.  
> **Interactive Hook:** Invoked automatically in `~/.bashrc` on interactive SSH login.

---

## 1. OPERATIONAL NOTES

* Downloads are staged strictly in RAM tmpfs (`/tmp`) during installation to prevent NAND flash wear.
* Fastfetch reads battery voltage and thermals directly from Linux kernel sysfs (`/sys/class/power_supply` and `/sys/class/thermal`).