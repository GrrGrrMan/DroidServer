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
