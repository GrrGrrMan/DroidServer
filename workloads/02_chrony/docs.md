# Chrony NTP Time Synchronization (`02_chrony`)

> **Role:** High-accuracy NTP timekeeping daemon.  
> **Lifecycle:** Supervised by Root PM2 (`chrony`).  
> **Log Buffer:** `/dev/shm/chrony.log` (RAM tmpfs).

---

## 1. OPERATIONAL SPECIFICATION

* **Upstream Time Servers:** `time.cloudflare.com`, `time.google.com` (with `iburst` fast sync)
* **Step Threshold:** Clocks slewed > 1.0s are stepped immediately on boot (`makestep 1.0 3`).
* **RTC Sync:** Automatically syncs hardware RTC clocks (`rtcsync`).
* **State Directory:** `/var/lib/chrony/chrony.drift` (persisted on UFS).