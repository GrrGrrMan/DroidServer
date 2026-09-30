# 01_SERVICES (Dynamic Workload Dashboard)

> **Role:** Parent management dashboard for userland servers, developer tooling, IoT brokers, and resilience daemons running inside the Debian 12 ARM64 container.  
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
echo "=== Root PM2 Daemons ==="
/data/local/bin/chroot-debian.sh "pm2 list"
echo ""
echo "=== User (oppo) PM2 Daemons ==="
/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 list'"
'@ | adb -s 192.168.1.35:5555 shell su
```

---

## 2. WORKLOAD HYGIENE RULES

### The Systemd Absence Constraint

Because the Debian userland runs inside an Android-managed Linux mount namespace without systemd as PID 1, all `systemctl` commands will fail. All background daemons and scripts must be supervised via:

* **PM2:** Default process supervisor for Node.js, Python virtualenvs, and background shell scripts.  
* **Traditional POSIX `/etc/init.d/` Scripts:** Used for system packages with legacy sysvinit wrappers (e.g., Mosquitto).  
* **Standalone Foreground Wrappers:** Launched within persistent terminal multiplexers (`tmux` / `screen`) with direct PID capture.

### Network Namespace Parity

The Debian chroot shares the network stack, loopback interface, and local IP (`192.168.1.35`) directly with the Android host:

* **Port Collision Rule:** **NEVER** bind a container service to port `5555` (permanently reserved for host ADB).  
* **Privileged Ports:** Container services running under root (UID 0) can bind directly to standard low ports (e.g., `:22`, `:80`, `:123`, `:1883`, `:20128`).

### Flash Wear Minimization (UFS 2.1 Longevity)

The device uses soldered, non-replaceable UFS 2.1 NAND flash:

* All high-frequency runtime logs are routed to volatile RAM via `/dev/shm/[service_name].log` (tmpfs).  
* Both Root and User PM2 instances are bounded via `pm2-logrotate` (5 MB per log, 3 rotations retained) to prevent `/dev/shm` tmpfs memory exhaustion.

### The Headless Automation & Scraper Boundary

* **STRICT PROHIBITION:** Never deploy full headless browser runtimes (`chromium`, `puppeteer`, `playwright`) or Android GUI automation (`uiautomator`) inside this machine.  
* **Reasoning:** Android kernel namespace restrictions (`CLONE_NEWUSER`) break Chromium sandbox models, heavy browser processes trigger thermal throttling on Cortex-A73 cores, and running GUI tools requires resurrecting Android’s Zygote (wasting ~3.5 GB of RAM).  
* **Ingestion Architectural Standard:** Workloads requiring web extraction (such as the AliExpress evaluation engine) must use client-side browser DOM extraction (Bookmarklets / Tampermonkey scripts on your workstation) that send structured JSON payloads to local container API endpoints.

---

## 3. ACTIVE PORT & SERVICE REGISTRY

| Service / Daemon | Port / Endpoint | Protocol / User | Lifecycle Supervisor |
| :--- | :--- | :--- | :--- |
| **Host ADB Daemon** | TCP `:5555` | Android Host (`adbd`) | Android init (`00_server_init.sh`) |
| **Debian OpenSSH** | TCP `:22` | Debian Root / `oppo` | `chroot-debian.sh` (`/usr/sbin/sshd`) |
| **Tailscale Daemon** | WireGuard / Mesh (`100.x.y.z`) | Debian Root | Root PM2 (`tailscaled`) |
| **Chrony NTP** | UDP `:123` (Client) | Debian Root | Root PM2 (`chrony`) |
| **Network Watchdog** | Layer 3 Keepalive | Debian Root | Root PM2 (`net-watchdog`) |
| **PM2 Logrotate** | Memory Guard (5MB cap) | Debian Root & `oppo` | PM2 Module (`pm2-logrotate`) |
| **Docsify Portal** | TCP `:8080` | Debian (`oppo`) | User PM2 (`docs-portal`) |
| **Mosquitto MQTT** | TCP `:1883` | Debian (`mosquitto`) | `/etc/init.d/mosquitto` (Pending) |
| **OmniRoute Proxy** | TCP `:20128` | Debian (`oppo`) | User PM2 (`omniroute` - Pending) |
| **AliShopper Worker**| TCP `:20129` | Debian (`oppo`) | User PM2 (`alishopper` - Pending) |
| **PaperMC Server** | TCP `:25565` | Debian (`oppo`) | `tmux` / `screen` session (Pending) |

---

## 4. THE SERVICE MODULE CONTRACT

To deploy a new service, daemon, or background workload to this machine:

1. **Do not** add operational parameters or service commands directly to this dashboard tab.  
2. Duplicate the clean contract located in the child tab `_TEMPLATE` into a new sub-tab under `01_SERVICES` (e.g., `01_SERVICES/OmniRoute`, `01_SERVICES/AliShopper`).  
3. Fill out the operational parameters, lifecycle commands, and memory limits according to the template contract.