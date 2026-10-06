# Chroot_Engine (Sub-Tab: 00_PLATFORM)

> **Scope:** Native Debian 12 (Bookworm) ARM64 container runtime, kernel mount namespace bindings, setuid filesystem permissions, non-root user network access, OpenSSH daemon management, total UFS flash cache redirection (`/dev/shm`, `/run`, `/tmp`), host filesystem bind-mounting, and the surgical headless memory reclaim mechanism.  
> **Blast Radius:** **MEDIUM TO HIGH**. Errors here invalidate userland permissions, break setuid execution for `sudo`, drop SSH terminal allocation, or lock non-root users out of the network stack.

---

## 1. MOUNT NAMESPACE HIERARCHY

The native chroot executes directly atop the phone's Android Linux kernel (`4.14.186+`) with zero virtualization overhead. The following host kernel virtual filesystems, volatile tmpfs buffers, and host directories are bound into `/data/local/debian/`:

```text
/data/local/debian/
├── proc/          <── [procfs]  Kernel process tables and CPU stats
├── sys/           <── [sysfs]   Kernel hardware device tree and power control
├── dev/           <── [bind]    Hardware device nodes (/dev/urandom, null, zero)
├── dev/pts/       <── [devpts]  Virtual pseudo-terminal slaves (Mandatory for SSH/PTY)
├── dev/shm/       <── [tmpfs]   Shared memory buffer in RAM (512 MB tmpfs; volatile logs/caches)
├── run/           <── [tmpfs]   Volatile runtime sockets, PIDs, and lockfiles (tmpfs, mode 0755)
├── tmp/           <── [tmpfs]   Volatile compiler, pip, and IPC scratchpad (256 MB tmpfs, mode 1777)
├── mnt/adb/       <── [bind]    Android Magisk root directory (/data/adb)
└── mnt/host-bin/  <── [bind]    Android host script directory (/data/local/bin)
```

* **Total Expected Active Mounts:** Exactly `9`.

---

## 2. MASTER CONTAINER RUNTIME SCRIPT

This master host script handles filesystem binding, host bind-mount exposition, SUID flag enforcement on `/data`, hostname synchronization, DNS configuration, environment sanitization, and container entry.

* **Host Path:** `/data/local/bin/chroot-debian.sh`  
* **Host Permissions:** `755` (`-rwxr-xr-x`)
* **Mount Guarding:** Mount checks parse `/proc/mounts` directly to prevent duplicate mount stacking bugs caused by Toybox `mountpoint` false-negatives on same-filesystem bind mounts.

**`[Host:Android#]`**
```bash
#!/system/bin/sh
CHROOT_DIR="/data/local/debian"

# 0. Enforce host network hostname and setuid binaries on /data
setprop net.hostname oppo
mount -o remount,suid /data

# 1. Mount virtual kernel filesystems using /proc/mounts checks (prevents duplicate stacking)
grep -qs " $CHROOT_DIR/proc " /proc/mounts || mount -t proc proc "$CHROOT_DIR/proc"
grep -qs " $CHROOT_DIR/sys " /proc/mounts  || mount -t sysfs sys "$CHROOT_DIR/sys"
grep -qs " $CHROOT_DIR/dev " /proc/mounts  || mount -o bind /dev "$CHROOT_DIR/dev"

# Ensure target directories exist
mkdir -p "$CHROOT_DIR/dev/pts"
mkdir -p "$CHROOT_DIR/dev/shm"
mkdir -p "$CHROOT_DIR/run"
mkdir -p "$CHROOT_DIR/tmp"
mkdir -p "$CHROOT_DIR/mnt/adb"
mkdir -p "$CHROOT_DIR/mnt/host-bin"

# Mount pseudo-terminals and in-memory tmpfs partitions (Total 9 mounts)
grep -qs " $CHROOT_DIR/dev/pts " /proc/mounts || mount -t devpts devpts -o rw,nosuid,noexec,relatime,mode=600,ptmxmode=0666 "$CHROOT_DIR/dev/pts"
grep -qs " $CHROOT_DIR/dev/shm " /proc/mounts || mount -t tmpfs tmpfs -o size=512M "$CHROOT_DIR/dev/shm"
grep -qs " $CHROOT_DIR/run " /proc/mounts     || mount -t tmpfs tmpfs -o mode=0755,nosuid,nodev "$CHROOT_DIR/run"
grep -qs " $CHROOT_DIR/tmp " /proc/mounts     || mount -t tmpfs tmpfs -o mode=1777,nosuid,nodev,size=256M "$CHROOT_DIR/tmp"

# Host bind mounts for maintenance (Guarded against same-filesystem mountpoint bugs)
grep -qs " $CHROOT_DIR/mnt/adb " /proc/mounts      || mount -o bind /data/adb "$CHROOT_DIR/mnt/adb"
grep -qs " $CHROOT_DIR/mnt/host-bin " /proc/mounts || mount -o bind /data/local/bin "$CHROOT_DIR/mnt/host-bin"

# Pre-create runtime socket directories on tmpfs with strict POSIX permissions
mkdir -p "$CHROOT_DIR/run/tailscale"
mkdir -p "$CHROOT_DIR/run/sshd"
chmod 0755 "$CHROOT_DIR/run/tailscale"
chmod 0755 "$CHROOT_DIR/run/sshd"

# 2. Sync host DNS nameserver
NAMESERVER=$(getprop net.dns1)
[ -n "$NAMESERVER" ] && echo "nameserver $NAMESERVER" > "$CHROOT_DIR/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "$CHROOT_DIR/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "$CHROOT_DIR/etc/resolv.conf"

# 3. Clean POSIX Linux environment definition
ENV_CMD="/usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root USER=root TERM=xterm-256color LANG=C.UTF-8"

# 4. Execute passed command or open interactive bash login shell
if [ -n "$1" ]; then
  chroot "$CHROOT_DIR" $ENV_CMD /bin/bash -c "$*"
else
  chroot "$CHROOT_DIR" $ENV_CMD /bin/bash --login
fi
```

---

## 3. USER PROVISIONING & ANDROID NETWORK PERMISSIONS (AID_INET)

Android kernels enforce Paranoid Network Routing (restricting raw socket creation to specific Android GIDs). Standard Linux non-root users must belong to group `aid_inet` (GID 3003) to open TCP/UDP sockets without root privileges.

### Standard User Configuration (`oppo`)

* **Username:** `oppo` (UID 1000)  
* **Administrative Access:** Passwordless `sudo` via `/etc/sudoers.d/oppo`  
* **Network Clearance Groups:** `aid_inet` (3003), `aid_net_raw` (3004)

**`[Debian:root#]`**
```bash
groupadd -g 3003 aid_inet 2>/dev/null || true
groupadd -g 3004 aid_net_raw 2>/dev/null || true
usermod -aG sudo,adm,users,aid_inet,aid_net_raw oppo
echo "oppo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/oppo
chmod 0440 /etc/sudoers.d/oppo
```

---

## 4. HOSTNAME & OPENSSH REMOTE ACCESS

* **Machine Hostname:** `oppo`  
* **Static Network Endpoint:** `192.168.1.35:22`  
* **Primary SSH Account:** `oppo@192.168.1.35`  
* **Tailscale Remote SSH:** `oppo@oppo-server` (Passwordless / Keyless)

---

## 5. UFS FLASH PROTECTION & VOLATILE RUNTIME CACHING

The device uses soldered, non-replaceable UFS 2.1 NAND flash. All volatile runtime caching, temporary sockets, bytecode compilation, and daemon logs are completely pinned to RAM tmpfs buffers:

1. **`/dev/shm` (512 MB tmpfs):** Application logs, `.cache/pip`, and `.npm`.
2. **`/run` (tmpfs):** OpenSSH runtime state and UNIX sockets (`/run/tailscale/tailscaled.sock`).
3. **`/tmp` (256 MB tmpfs):** Build artifacts, apt staging buffers, and ephemeral lockfiles.
4. **Log Rotation Bounds:** Supervised via `log-guard` (`workloads/03_log_guard`), a lightweight 3 MB POSIX daemon capping logs at 5 MB with 2 retained backups.

---

## 6. PERSISTENT CONTAINER AUTOSTART & RESURRECTION (service.d)

Managed by the unified platform init script `/data/adb/service.d/00_server_init.sh` on cold boot:
1. Waits for valid IPv4 network lease on `wlan0`.
2. Locks the default gateway in routing table `main`.
3. Brings up Debian, starts OpenSSH, and resurrects Root PM2 (Tailscale, Chrony, Net-Watchdog) and User PM2 (Docsify).
4. Reclaims ~3.5 GB of RAM using surgical `ctl.stop` triggers on Zygote and SurfaceFlinger, preserving the native Linux `netd` daemon.

---

## 7. TRIAGE & FAILURE MODES

| Symptom | Probable Root Cause | Resolution Protocol |
| :--- | :--- | :--- |
| **Active mount count exceeds 9 (mount leak)** | Legacy `mountpoint -q` checks failed to detect bind mounts on the same filesystem. | Verify `chroot-debian.sh` uses `grep -qs " ... " /proc/mounts`. Peel duplicates with `umount -l /data/local/debian/mnt/*`. |
| **`special device /data/local/bin does not exist` when mounting from SSH** | Running `mount -o bind` from inside Debian. The container cannot see outside its jail; the host must push the bind-mount. | Define bind mounts exclusively within `/data/local/bin/chroot-debian.sh` on the Android host. |
| **PM2 services do not auto-start after cold boot** | Missing quotes or improper argument passing in `00_server_init.sh`. | Verify `00_server_init.sh` invokes `/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 resurrect'"`. |
| **`sudo: effective uid is not 0, nosuid error`** | The `/data` partition was remounted without the `suid` flag. | Run `mount -o remount,suid /data` on the Android host. |
| **`Connection refused` on SSH (:22) after cold boot** | OpenSSH privsep directory `/run/sshd` on fresh tmpfs was group/world-writable (rejected by sshd). | Ensure `chroot-debian.sh` enforces `chmod 0755 "$CHROOT_DIR/run/sshd"`. Reset via `chmod 0755 /data/local/debian/run/sshd && /data/local/bin/chroot-debian.sh /usr/sbin/sshd`. |