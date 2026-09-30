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