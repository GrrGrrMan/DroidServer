$TARGET = "192.168.1.35:5555"
Write-Host ">>> Pushing Hardened Host Platform Scripts to $TARGET..." -ForegroundColor Cyan

# 1. Push container runtime script
adb -s $TARGET push host/bin/chroot-debian.sh /data/local/tmp/chroot-debian.sh
adb -s $TARGET shell "su -c 'mv /data/local/tmp/chroot-debian.sh /data/local/bin/chroot-debian.sh && chmod 755 /data/local/bin/chroot-debian.sh'"

# 2. Push consolidated server init script and purge obsolete legacy scripts on phone
adb -s $TARGET push host/service.d/00_server_init.sh /data/local/tmp/00_server_init.sh
adb -s $TARGET shell "su -c '
  mv /data/local/tmp/00_server_init.sh /data/adb/service.d/00_server_init.sh;
  chmod 755 /data/adb/service.d/00_server_init.sh;
  rm -f /data/adb/service.d/00_platform_init.sh;
  rm -f /data/adb/service.d/01_chroot_init.sh;
'"

Write-Host ">>> Host platform scripts successfully updated and legacy init scripts purged." -ForegroundColor Green