# _TEMPLATE (Sub-Tab: 01_SERVICES)

> **Scope:** [One-line executive summary of application purpose and function].  
> **Port / Endpoint:** Protocol, port number, or local UNIX socket (e.g., `TCP :1883`, `TCP :20128`).  
> **Health Check:** `curl -sI http://127.0.0.1:[PORT] | head -n 1` *(or protocol-specific ping command)*

---

## 1. LIFECYCLE (OPERATIONS)

All lifecycle operations are executed inside the Debian container userland. Standard services are supervised via PM2 under the unprivileged `oppo` user (or `root` if binding privileged system ports <1024).

### Start Daemon

**`[Debian:oppo$]`**
```bash
pm2 start /path/to/daemon --name "[service_name]" \
  --output /dev/shm/[service_name].log \
  --error /dev/shm/[service_name].err \
  -- [runtime-arguments]
```

### Stop Daemon

**`[Debian:oppo$]`**
```bash
pm2 stop [service_name]
```

### Restart Daemon

**`[Debian:oppo$]`**
```bash
pm2 restart [service_name]
```

### View Live Logs (RAM Buffer)

**`[Debian:oppo$]`**
```bash
tail -n 50 -f /dev/shm/[service_name].log
```

---

## 2. CONFIGURATION & PATHS

| Component | Absolute Path (Inside Chroot) | Description |
| :--- | :--- | :--- |
| **Binary Executable** | `/usr/bin/[service_name]` or `/usr/local/bin/[service_name]` | Primary binary or Node/Python entry script |
| **Configuration File** | `/etc/[service_name]/[service_name].conf` | Main application configuration file |
| **Persistent Data Dir** | `/var/lib/[service_name]/` | Database, keys, and state stored safely on UFS flash |
| **Volatile Logs** | `/dev/shm/[service_name].log`, `.err` | In-memory runtime output directed to tmpfs in RAM |
| **PM2 Process Config** | `/home/oppo/.pm2/dump.pm2` | Saved state table for cold-boot auto-resurrection |

---

## 3. TRIAGE & FAILURE MODES

| Symptom | Probable Root Cause | Resolution Protocol |
| :--- | :--- | :--- |
| **Endpoint connection refused or socket hang** | Process crashed on startup, exceeded memory quota, or encountered port collision. | 1. Check free memory: `free -m`<br>2. Inspect logs: `cat /dev/shm/[service_name].err \| tail -n 50`<br>3. Verify port availability: `ss -tulpn \| grep :[PORT]`<br>4. Restart service. |
| **Process consumes >90% CPU on Cortex-A73 cores** | Unhandled loop, thread deadlock, or upstream network socket timeout. | 1. Identify runaway PID: `ps -eo pid,user,comm,%cpu --sort=-%cpu \| head -n 5`<br>2. Terminate PID: `kill -9 [PID]`<br>3. Verify network upstream reachability before restarting. |
| **Socket throws `[Errno 13] Permission denied`** | Service user lacks Android kernel network group clearance. | Add service user to Android socket group: `sudo usermod -aG aid_inet [user]`, then restart daemon. |

---

## 4. PURGE & CLEANUP

To completely remove the service and release all system resources:

**`[Debian:oppo$]`**
```bash
# 1. Stop and unregister from PM2 supervisor
pm2 delete [service_name] && pm2 save

# 2. Purge Debian package (if installed via APT)
sudo apt-get purge -y [package_name] && sudo apt-get autoremove -y

# 3. Clean filesystems (configuration, persistent data, and RAM buffers)
sudo rm -rf /etc/[service_name]
sudo rm -rf /var/lib/[service_name]
rm -f /dev/shm/[service_name].log /dev/shm/[service_name].err
```