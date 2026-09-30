# Tailscale (Sub-Tab: 01_SERVICES)

> **Scope:** Encrypted mesh VPN overlay and remote passwordless Tailscale SSH daemon for out-of-band management.  
> **Port / Endpoint:** Tailnet Overlay IP (`100.x.y.z`) | Local IPC: `/run/tailscale/tailscaled.sock` | WireGuard UDP: `:41641`  
> **Health Check:** `tailscale status && tailscale ip -4`

---

## 1. LIFECYCLE (OPERATIONS)

All lifecycle operations are supervised by PM2 running under `root` inside the Debian container.

### Start Daemon

**`[Debian:oppo$]`**
```bash
sudo pm2 start tailscaled
```

### Stop Daemon

**`[Debian:oppo$]`**
```bash
sudo pm2 stop tailscaled
```

### Restart Daemon

**`[Debian:oppo$]`**
```bash
sudo pm2 restart tailscaled
```

### View Live Handshake / Debug Logs (RAM Buffer)

**`[Debian:oppo$]`**
```bash
tail -n 50 -f /dev/shm/tailscaled.err
```

---

## 2. CONFIGURATION & PATHS

| Component | Absolute Path (Inside Chroot) | Description |
| :--- | :--- | :--- |
| **Daemon Binary** | `/usr/sbin/tailscaled` | Main Go WireGuard/routing daemon |
| **CLI Binary** | `/usr/bin/tailscale` | Command-line management tool |
| **Runtime Socket** | `/run/tailscale/tailscaled.sock` | Local UNIX domain control socket |
| **Persistent State** | `/var/lib/tailscale/tailscaled.state` | Node credentials and machine key on UFS |
| **Volatile Logs** | `/dev/shm/tailscaled.log`, `.err` | In-memory stderr/stdout handshake logs |
| **PM2 Process Config** | `/root/.pm2/dump.pm2` | Saved process state for auto-resurrection |

### Mandatory Runtime Invariant

Tailscale **MUST** be launched with `--tun=userspace-networking`. Attempting to use default kernel TUN devices will trigger Android kernel `fwmark` (`SO_MARK`) collisions with Android's `netd` routing tables, resulting in immediate `connect: network is unreachable` errors.

### PM2 Launch Definition

**`[Debian:oppo$]`**
```bash
sudo pm2 start /usr/sbin/tailscaled --name tailscaled \
  --output /dev/shm/tailscaled.log \
  --error /dev/shm/tailscaled.err \
  -- --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock
```

---

## 3. REMOTE ACCESS & TAILSCALE SSH

With Tailscale active, the server is accessible outside the local area network without port forwarding or dynamic DNS.

### A. Tailscale SSH (Keyless / Passwordless)

From any workstation, laptop, or mobile terminal connected to your Tailnet:

**`[Workstation:Terminal]`**
```bash
ssh oppo@oppo-server
# Or via Tailscale IP:
ssh oppo@100.x.y.z
```

### B. Exposing Container Services (Tailscale Serve)

To securely proxy container HTTP services (such as OmniRoute `:20128`) over the encrypted Tailnet:

**`[Debian:oppo$]`**
```bash
sudo tailscale serve --bg 20128
# Service becomes available privately at: http://oppo-server:20128
```

---

## 4. TRIAGE & FAILURE MODES

| Symptom | Probable Root Cause | Resolution Protocol |
| :--- | :--- | :--- |
| **Dialing control plane returns `connect: network is unreachable`** | `tailscaled` was started without `--tun=userspace-networking`. Tailscale's default `SO_MARK` (bits 16–23) collides with Android 11's `netd` policy routing tables (`ip rule`), dropping egress packets. | Stop the process, verify the `--tun=userspace-networking` flag is present in PM2 arguments, and restart. |
| **`failed to connect to local tailscaled; it doesn't appear to be running`** | The daemon crashed or socket `/run/tailscale/tailscaled.sock` is missing. | Inspect PM2 status via `sudo pm2 status` and check `/dev/shm/tailscaled.err`. Ensure directory `/run/tailscale` exists. |
| **Machine shows "Offline" in Tailscale Admin Console after soft-restart** | PM2 root state was not restored after userland cycle. | Run `sudo pm2 resurrect` or ensure container autostart script executes root PM2 resurrection. |

---

## 5. PURGE & CLEANUP

To completely remove Tailscale and purge its persistent machine keys:

**`[Debian:oppo$]`**
```bash
# 1. Stop and remove from PM2
sudo pm2 delete tailscaled && sudo pm2 save

# 2. Purge Debian package
sudo apt-get purge -y tailscale && sudo apt-get autoremove -y

# 3. Clean filesystems (keys, sockets, and RAM logs)
sudo rm -rf /var/lib/tailscale /run/tailscale
sudo rm -f /dev/shm/tailscaled.log /dev/shm/tailscaled.err
sudo rm -f /etc/apt/sources.list.d/tailscale.list
sudo rm -f /usr/share/keyrings/tailscale-archive-keyring.gpg
```