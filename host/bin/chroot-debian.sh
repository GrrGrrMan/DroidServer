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
