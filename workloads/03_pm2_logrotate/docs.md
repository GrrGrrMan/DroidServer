# PM2 Logrotate Guard (`03_pm2_logrotate`)

> **Role:** Bounded memory guard protecting RAM tmpfs buffers (`/dev/shm`) from saturation.  
> **Lifecycle:** Embedded PM2 module across Root and User (`oppo`) instances.

---

## 1. BOUNDS & POLICIES

* **Max File Size:** `5M` (Rotates log when exceeding 5 megabytes)
* **Retention Count:** `3` (Maintains current + 3 historical rotations; purges older files)
* **Compression:** `false` (Avoids unnecessary CPU cycles on Cortex-A73/A53 cores)