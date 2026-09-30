# Chroot_Engine (Sub-Tab: 00_PLATFORM)

> **Scope:** Native Debian 12 (Bookworm) ARM64 container runtime, kernel mount namespace bindings, setuid filesystem permissions, non-root user network access, OpenSSH daemon management, UFS flash cache redirection, host filesystem bind-mounting, and the headless `stop` memory reclaim mechanism.  
> **Blast Radius:** **MEDIUM TO HIGH**. Errors here invalidate userland permissions, break setuid execution for `sudo`, drop SSH terminal allocation, or lock non-root users out of the network stack.

---

## 1. MOUNT NAMESPACE HIERARCHY

The native chroot executes directly atop the phone's Android Linux kernel (`4.14.186+`) with zero virtualization overhead. The following host kernel virtual filesystems and host directories are bound into `/data/local/debian/`:

```text
/data/local/debian/
├── proc/          <── [procfs]  Kernel process tables and CPU stats
├── sys/           <── [sysfs]   Kernel hardware device tree and power control
├── dev/           <── [bind]    Hardware device nodes (/dev/urandom, null, zero)
├── dev/pts/       <── [devpts]  Virtual pseudo-terminal slaves (Mandatory for SSH/PTY)
├── dev/shm/       <── [tmpfs]   Shared memory buffer in RAM (512 MB tmpfs; protects UFS flash)
├── mnt/adb/       <── [bind]    Android Magisk root directory (/data/adb)
└── mnt/host-bin/  <── [bind]    Android host script directory (/data/local/bin)
```

* **Total Expected Active Mounts:** Exactly `7`.

---

## 2. MASTER CONTAINER RUNTIME SCRIPT

This master host script handles filesystem binding, host bind-mount exposition, SUID flag enforcement on `/data`, hostname synchronization, DNS configuration, environment sanitization, and container entry.

* **Host Path:** `/data/local/bin/chroot-debian.sh`  
* **Host Permissions:** `755` (`-rwxr-xr-x`)

**`[Host:Android#]`**
```bash
#!/system/bin/sh
CHROOT_DIR="/data/local/debian"

# 0. Enforce host network hostname and setuid binaries on /data
setprop net.hostname oppo
mount -o remount,suid /data

# 1. Mount virtual kernel filesystems and host directories if not active
mountpoint -q "$CHROOT_DIR/proc" || mount -t proc proc "$CHROOT_DIR/proc"
mountpoint -q "$CHROOT_DIR/sys" || mount -t sysfs sys "$CHROOT_DIR/sys"
mountpoint -q "$CHROOT_DIR/dev" || mount -o bind /dev "$CHROOT_DIR/dev"

mkdir -p "$CHROOT_DIR/dev/pts"
mkdir -p "$CHROOT_DIR/dev/shm"
mkdir -p "$CHROOT_DIR/mnt/adb"
mkdir -p "$CHROOT_DIR/mnt/host-bin"

mountpoint -q "$CHROOT_DIR/dev/pts" || mount -t devpts devpts "$CHROOT_DIR/dev/pts"
mountpoint -q "$CHROOT_DIR/dev/shm" || mount -t tmpfs tmpfs -o size=512M "$CHROOT_DIR/dev/shm"
mountpoint -q "$CHROOT_DIR/mnt/adb" || mount -o bind /data/adb "$CHROOT_DIR/mnt/adb"
mountpoint -q "$CHROOT_DIR/mnt/host-bin" || mount -o bind /data/local/bin "$CHROOT_DIR/mnt/host-bin"

# 2. Sync host DNS nameserver
NAMESERVER=$(getprop net.dns1)
[ -n "$NAMESERVER" ] && echo "nameserver $NAMESERVER" > "$CHROOT_DIR/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "$CHROOT_DIR/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "$CHROOT_DIR/etc/resolv.conf"

# 3. Clean POSIX Linux environment definition
ENV_CMD="/usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root USER=root TERM=xterm-256color LANG=C.UTF-8"

# 4. Execute passed command or open interactive bash login shell
if [ -n "$1" ]; then
  chroot "$CHROOT_DIR" $ENV_CMD /bin/bash -c "$@"
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

### Host Configuration Files

`/etc/hostname`:
```text
oppo
```

`/etc/hosts`:
```text
127.0.0.1   localhost oppo
::1         localhost ip6-localhost ip6-loopback
192.168.1.35 oppo
```

---

## 5. UFS FLASH PROTECTION & VOLATILE RUNTIME CACHING

The device uses soldered, non-replaceable UFS 2.1 NAND flash. All volatile runtime caching and bytecode compilation are pinned to RAM (`/dev/shm` tmpfs) to eliminate flash wear:

### A. Userland Shell Environment (`~/.bashrc`)

**`[Debian:oppo$]`**
```bash
export PIP_CACHE_DIR="/dev/shm/.cache/pip"
export PYTHONPYCACHEPREFIX="/dev/shm/.pycache"
```

### B. Node Package Manager Configuration (`~/.npmrc`)

**`[Debian:oppo$]`**
```bash
npm config set cache /dev/shm/.npm
```

---

## 6. PERSISTENT CONTAINER AUTOSTART & RESURRECTION (service.d)

Brings up Debian, starts OpenSSH, resurrects both root and user PM2 daemons (Tailscale + OmniRoute), and triggers the headless memory reclaim on cold boot:

* **Host Path:** `/data/adb/service.d/01_chroot_init.sh`  
* **Host Permissions:** `755` (`-rwxr-xr-x`)

**`[Host:Android#]`**
```bash
#!/system/bin/sh
# Wait until Android framework & network layer are fully initialized
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 3
done

# 1. Mount virtual filesystems and launch OpenSSH daemon
/data/local/bin/chroot-debian.sh "/usr/sbin/sshd"

# 2. Resurrect Root PM2 (Restores Tailscale)
/data/local/bin/chroot-debian.sh "pm2 resurrect"

# 3. Resurrect User PM2 (Restores OmniRoute and application daemons)
/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 resurrect'"

# 4. Wait 20 seconds for network interfaces and tunnels to settle
sleep 20

# 5. Headless Kill-Switch: Reclaim ~3.5 GB of RAM from dead UI
stop
```

---

## 7. INTERACTIVE HOST EDITING WORKFLOW (/mnt/adb & /mnt/host-bin)

Because `/data/adb` and `/data/local/bin` are bind-mounted inside Debian, host platform scripts can be edited directly inside SSH using standard terminal editors (`nano`, `micro`) without needing ADB pipes or PowerShell escaping.

**`[Debian:oppo$]`**
```bash
# Edit Magisk platform init scripts:
sudo nano /mnt/adb/service.d/01_chroot_init.sh

# Edit master container mount script:
sudo nano /mnt/host-bin/chroot-debian.sh
```

> **Operational Guardrail:** Treat `/mnt/adb` and `/mnt/host-bin` as frozen maintenance backdoors. Daily services and daemons must be added via PM2 inside Debian userland rather than modifying host startup scripts.

---

## 8. USERLAND CONTAINER SOFT-RESTART PROTOCOL

Because software warm-reboots drop the MT6358 PMIC rails and trigger an unrecoverable power-off state on this hardware, **NEVER** reboot the Android host. Use this soft-restart protocol to reload services or recover from userland crashes:

### From Management Workstation (PowerShell)

**`[Workstation:PS>]`**
```powershell
adb -s 192.168.1.35:5555 shell "su -c 'pkill -u oppo; /data/local/bin/chroot-debian.sh /usr/sbin/sshd'"
```

### From Inside Debian Container

**`[Debian:oppo$]`**
```bash
sudo pkill -TERM -u oppo && sudo /usr/sbin/sshd
```

---

## 9. TRIAGE & FAILURE MODES

| Symptom | Probable Root Cause | Resolution Protocol |
| :--- | :--- | :--- |
| **`/mnt/host-bin` or `/mnt/adb` is empty inside Debian** | Host bind-mount lines in `/data/local/bin/chroot-debian.sh` have not executed. | Verify host mount points via `su -c 'mount \| grep mnt'` or restart the container. |
| **`special device /data/local/bin does not exist` when mounting from SSH** | Running `mount -o bind` from inside Debian. The container cannot see outside its jail; the host must push the bind-mount into `/data/local/debian/`. | Define bind mounts exclusively within `/data/local/bin/chroot-debian.sh` on the Android host. |
| **PM2 services do not auto-start after cold boot** | Line 3 in `/data/adb/service.d/01_chroot_init.sh` is missing single quotes around `pm2 resurrect`. | Open `/mnt/adb/service.d/01_chroot_init.sh` in `nano` and ensure it reads `su - oppo -c 'pm2 resurrect'`. |
| **`sudo: effective uid is not 0, nosuid error`** | The `/data` partition was remounted without the `suid` flag. | Run `mount -o remount,suid /data` on the Android host. |