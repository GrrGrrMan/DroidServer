# 01_SERVICES (Dynamic Workload Dashboard)

> **Role:** Parent management dashboard for userland servers, developer tooling, IoT brokers, and AI proxy gateways running inside the Debian 12 ARM64 container.  
> **Blast Radius:** **LOW (ISOLATED)**. Failures here impact only specific userland applications. The underlying Linux kernel, Android host OS, network layer, and physical power delivery remain 100% stable.

---

## 1. DYNAMIC WORKLOAD DISCOVERY

Never hardcode service names into master monitoring scripts. Run these commands from your management workstation (over wireless ADB) or inside an elevated Android shell to inspect container state dynamically:

### A. Discover All Listening Ports and PIDs

**`[Workstation:PS>]`**
```powershell
@'
/data/local/bin/chroot-debian.sh "ss -tulpn | grep LISTEN"
'@ | adb -s 192.168.1.35:5555 shell su
```

### B. Discover Top Memory & CPU Consuming Container Services

**`[Workstation:PS>]`**
```powershell
@'
/data/local/bin/chroot-debian.sh "ps -eo pid,user,comm,%mem,%cpu --sort=-%mem | head -n 15"
'@ | adb -s 192.168.1.35:5555 shell su
```

### C. Check PM2 Supervised Workloads

**`[Workstation:PS>]`**
```powershell
@'
/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 list'"
'@ | adb -s 192.168.1.35:5555 shell su
```
```powershell
adb -s 192.168.1.35:5555 shell "su -c 'chroot /data/local/debian ss -tulpn | grep LISTEN'"
```

### B. Discover Top Memory & CPU Consuming Container Services

**`[Workstation:PS>]`**
```powershell
adb -s 192.168.1.35:5555 shell "su -c 'chroot /data/local/debian ps -eo pid,user,comm,%mem,%cpu --sort=-%mem | head -n 15'"
```

### C. Check PM2 Supervised Workloads

**`[Workstation:PS>]`**
```powershell
adb -s 192.168.1.35:5555 shell "su -c 'chroot /data/local/debian su - oppo -c \"pm2 list\"'"
```

---

## 2. WORKLOAD HYGIENE RULES

### The Systemd Absence Constraint

Because the Debian userland runs inside an Android-managed Linux mount namespace without systemd as PID 1, all `systemctl` commands will fail. All background daemons and scripts must be supervised via:

* **PM2:** Default process supervisor for Node.js, Python virtualenvs, and shell background daemons.  
* **Traditional POSIX `/etc/init.d/` Scripts:** Used for system packages with legacy sysvinit wrappers (e.g., Mosquitto).  
* **Standalone Foreground Wrappers:** Launched within persistent terminal multiplexers (`tmux` / `screen`) with direct PID capture.

### Network Namespace Parity

The Debian chroot shares the network stack, loopback interface, and local IP (`192.168.1.35`) directly with the Android host:

* **Port Collision Rule:** **NEVER** bind a container service to port `5555` (permanently reserved for host ADB).  
* **Privileged Ports:** Container services running under root (UID 0) can bind directly to standard low ports (e.g., `:22`, `:80`, `:1883`, `:20128`).

### Flash Wear Minimization (UFS 2.1 Longevity)

The device uses soldered, non-replaceable UFS 2.1 NAND flash:

* High-frequency runtime logs must be routed to volatile RAM via `/dev/shm/[service_name].log` (tmpfs) rather than writing un-rotated log files to disk.  
* Configure all application-level log rotators with strict size boundaries (<10 MB).

### The Headless Automation & Scraper Boundary

* **STRICT PROHIBITION:** Never deploy full headless browser runtimes (`chromium`, `puppeteer`, `playwright`) or Android GUI automation (`uiautomator`) inside this machine.  
* **Reasoning:** Android kernel namespace restrictions (`CLONE_NEWUSER`) break Chromium sandbox models, heavy browser processes trigger thermal throttling on Cortex-A73 cores, and running GUI tools requires resurrecting Android’s Zygote (wasting ~3.5 GB of RAM).  
* **Ingestion Architectural Standard:** Workloads requiring web extraction (such as the AliExpress evaluation engine) must use client-side browser DOM extraction (Bookmarklets / Tampermonkey scripts on your workstation) that send structured JSON payloads to local container API endpoints.

---

## 3. ACTIVE PORT ALLOCATION REGISTRY

| Service / Daemon | Port / Endpoint | Protocol / User | Lifecycle Supervisor |
| :--- | :--- | :--- | :--- |
| **Host ADB Daemon** | TCP `:5555` | Android Host (`adbd`) | Android init (`service.d`) |
| **Debian OpenSSH** | TCP `:22` | Debian Root / `oppo` | `chroot-debian.sh` (`/usr/sbin/sshd`) |
| **Docsify Portal** | TCP `:8080` | Debian (`oppo`) | PM2 (`docs-portal`) |
| **Mosquitto MQTT** | TCP `:1883` | Debian (`mosquitto`) | `/etc/init.d/mosquitto` |
| **OmniRoute Proxy** | TCP `:20128` | Debian (`oppo`) | PM2 (`omniroute`) |
| **AliShopper Worker** | TCP `:20129` | Debian (`oppo`) | PM2 (`alishopper`) |
| **PaperMC Server** | TCP `:25565` | Debian (`oppo`) | `tmux` / `screen` session |

---

## 4. THE SERVICE MODULE CONTRACT

To deploy a new service, daemon, or background workload to this machine:

1. **Do not** add operational parameters or service commands directly to this dashboard tab.  
2. Duplicate the clean contract located in the child tab `_TEMPLATE` into a new sub-tab under `01_SERVICES` (e.g., `01_SERVICES/OmniRoute`, `01_SERVICES/AliShopper`).  
3. Fill out the operational parameters, lifecycle commands, and memory limits according to the template contract.