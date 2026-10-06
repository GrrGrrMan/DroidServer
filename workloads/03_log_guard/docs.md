# Log Guard Daemon (`03_log_guard`)

> **Role:** Lightweight POSIX memory guard protecting RAM tmpfs buffers (`/dev/shm`) from saturation.  
> **Lifecycle:** Supervised by Root PM2 (`log-guard`).  
> **Resource Footprint:** ~3.0 MB RAM (replaces dual Node.js runtimes).

---

## 1. BOUNDS & ROTATION POLICY

* **Target Directory:** `/dev/shm/*.log` and `/dev/shm/*.err` (all platform and user daemons)
* **Max File Size:** `5M` (Rotates log when exceeding 5 megabytes)
* **Retention Count:** `2` (`.1` and `.2` backups retained before purge)
* **Truncation Method:** In-place atomic truncation (`: > "$log"`) compatible with Linux `O_APPEND` file handles.