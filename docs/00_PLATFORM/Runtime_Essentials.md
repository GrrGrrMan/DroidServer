# Runtime_Essentials (Sub-Tab: 00_PLATFORM)

> **Scope:** Shared language runtime engines (Node.js 24 LTS, Python 3.11), PEP 668 packaging standards, PM2 userland process supervision, and soldered UFS 2.1 flash cache mitigation.  
> **Blast Radius:** **LOW TO MEDIUM**. Misconfiguration breaks language tooling, corrupts virtualenvs, or causes flash write thrashing, but leaves host Android and container filesystems intact.

---

## 1. RUNTIME ARCHITECTURE & ENGINE MATRIX

Because systemd is absent as PID 1 inside the Android chroot namespace, standard Linux runtime daemons are managed via PM2. All compilers, interpreters, and package caches adhere to the RAM-first flash wear mitigation rule:

| Runtime / Tool | Binary Path | Source / Version | Flash Protection Rule |
| :--- | :--- | :--- | :--- |
| **Node.js** | `/usr/bin/node` | NodeSource APT (`v24.x` LTS) | `npm` cache pinned to `/dev/shm/.npm` |
| **npm** | `/usr/bin/npm` | Bundled with Node 24 (`v11.x+`) | Global writes prohibited without root |
| **Python 3** | `/usr/bin/python3` | Debian 12 Upstream (`v3.11.2`) | `PYTHONPYCACHEPREFIX` in `/dev/shm/.pycache` |
| **pip** | `/usr/bin/pip3` | Debian 12 Upstream (PEP 668) | `PIP_CACHE_DIR` pinned to `/dev/shm/.cache/pip` |
| **PM2** | `/usr/bin/pm2` | Global npm package (Latest) | Process runtime logs streamed to `/dev/shm` |
| **Database / CLI** | `/usr/bin/sqlite3`, `/usr/bin/jq` | Debian 12 Upstream | Persistent DBs stored on flash in `/var/lib/` |
| **System Info / CLI**| `/usr/bin/fastfetch` | Upstream ARM64 Deb (`workloads/04_fastfetch`) | Download staged in RAM `/tmp` tmpfs |
| **Base CLI Suite** | `/usr/bin/htop`, `tmux`, `ncdu` | Debian 12 Upstream (`workloads/00_base`) | Declared in `packages.apt`; apt cache cleaned |
---

## 2. NODE.JS 24 LTS CANONICAL STACK (NODESOURCE)

The official NodeSource repository provides upstream pre-compiled ARM64 binaries linked against Debian 12's `glibc 2.36`, eliminating CPU-intensive source compilation.

### A. Repository Pinning & Installation

**`[Debian:oppo$]`**
```bash
# 1. Install repository keyring utilities
sudo apt update && sudo apt install -y ca-certificates curl gnupg

# 2. Import NodeSource GPG signing key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

# 3. Pin NodeSource repository to Node 24.x LTS
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

# 4. Install Node.js runtime and npm
sudo apt update && sudo apt install -y nodejs
```

### B. UFS Flash Protection (Userland `.npmrc`)

Configured at the user level to ensure cache files written to RAM tmpfs maintain unprivileged ownership:

**`[Debian:oppo$]`**
```bash
npm config set cache /dev/shm/.npm
rm -rf ~/.npm
npm config get cache
# Expect: /dev/shm/.npm
```

---

## 3. PYTHON 3.11 CANONICAL STACK (PEP 668 & VIRTUALENVS)

Debian 12 strictly enforces **PEP 668 (`EXTERNALLY-MANAGED`)** to protect system-level APT packages. All application-level Python packages must be installed inside dedicated virtual environments.

### A. Core Runtime Installation

**`[Debian:oppo$]`**
```bash
sudo apt update && sudo apt install -y python3-minimal python3-venv python3-pip
```

### B. Ephemeral RAM Redirection (`~/.bashrc`)

Route bytecode serialization (`.pyc`) and pip download tarballs to RAM tmpfs:

**`[Debian:oppo$]`**
```bash
cat << 'EOF' >> ~/.bashrc

# Ephemeral RAM redirection (UFS Flash Protection)
export PIP_CACHE_DIR="/dev/shm/.cache/pip"
export PYTHONPYCACHEPREFIX="/dev/shm/.pycache"
EOF

source ~/.bashrc
```

### C. Service Virtualenv Standard

To deploy any Python service under `01_SERVICES/`, isolate dependencies without mutating system packages:

**`[Debian:oppo$]`**
```bash
python3 -m venv /var/lib/[service_name]/venv
source /var/lib/[service_name]/venv/bin/activate
pip install -r requirements.txt
```

---

## 4. PROCESS SUPERVISION VIA PM2 (SYSTEMD ALTERNATIVE)

Because the chroot environment lacks an active systemd init daemon, PM2 functions as the primary POSIX process manager to supervise background Node.js and Python microservices.

### A. Global Installation

**`[Debian:oppo$]`**
```bash
sudo npm install -g pm2
```

### B. Service Lifecycle Standards

All services supervised by PM2 must stream logs to RAM tmpfs to protect soldered storage:

**`[Debian:oppo$]`**
```bash
# Starting a Node.js daemon:
pm2 start /path/to/app.js --name "[service_name]" \
  --output /dev/shm/[service_name].log \
  --error /dev/shm/[service_name].err

# Starting a Python daemon inside a virtualenv:
pm2 start /var/lib/[service]/venv/bin/python3 --name "[service_name]" \
  --output /dev/shm/[service_name].log \
  --error /dev/shm/[service_name].err \
  -- /var/lib/[service]/main.py

# Saving active process list for persistence:
pm2 save
```

### C. Auto-Revive Integration on Boot

To restore active PM2 workloads automatically after a container soft-restart or cold boot, ensure the following execution hook exists in `/data/adb/service.d/00_server_init.sh` on the Android host:

**`[Host:Android#]`**
```bash
/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 resurrect'"
```

---

## 5. SYSTEM INFORMATION & HARDWARE TELEMETRY (FASTFETCH)

For fast terminal system diagnostics without `systemd` or desktop dependencies, upstream `fastfetch` is used.

### Installation Standard (Flash Wear Protection)
Because Debian 12 Bookworm does not include `fastfetch` in its core repository, the upstream ARM64 release is staged strictly in RAM `tmpfs` (`/tmp`) before installation to prevent UFS flash wear:

```bash
curl -sL https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-aarch64.deb -o /tmp/fastfetch.deb
sudo apt install -y /tmp/fastfetch.deb
rm -f /tmp/fastfetch.deb
```

---

## 6. TRIAGE & FAILURE MODES

| Symptom | Probable Root Cause | Resolution Protocol |
| :--- | :--- | :--- |
| **`npm error code EACCES / mkdir '/usr/etc'`** | Executing `npm config set ... --global` as unprivileged user `oppo`. | Omit the `--global` flag so settings write to `/home/oppo/.npmrc`. |
| **`error: externally-managed-environment`** | Attempting to run `pip install` globally without an active virtual environment. | Create and activate a venv via `python3 -m venv /path/to/venv && source /path/to/venv/bin/activate`. **Do NOT** use `--break-system-packages`. |
| **Python or Node socket throws `[Errno 13] Permission denied` or `EACCES`** | User lacks Android kernel clearance group `aid_inet` (GID 3003). | Run `sudo usermod -aG aid_inet oppo`, log out of SSH, and reconnect. |
| **High CPU usage on Cortex-A73 cores caused by Node tools (`nodemon`, `vite`)** | Inotify polling issues across Android mount namespace boundaries. | Disable polling-based file watchers in production daemons; deploy static builds or direct scripts. |