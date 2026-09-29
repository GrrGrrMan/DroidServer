$TARGET = "192.168.1.35:5555"
Write-Host ">>> Pushing Host Platform Scripts to $TARGET..." -ForegroundColor Cyan

# Push container runtime script
adb -s $TARGET push host/bin/chroot-debian.sh /data/local/tmp/chroot-debian.sh
adb -s $TARGET shell "su -c 'mv /data/local/tmp/chroot-debian.sh /data/local/bin/chroot-debian.sh && chmod 755 /data/local/bin/chroot-debian.sh'"

# Push service.d init scripts
adb -s $TARGET push host/service.d/00_platform_init.sh /data/local/tmp/00_platform_init.sh
adb -s $TARGET push host/service.d/01_chroot_init.sh /data/local/tmp/01_chroot_init.sh
adb -s $TARGET shell "su -c '
  mv /data/local/tmp/00_platform_init.sh /data/adb/service.d/00_platform_init.sh;
  mv /data/local/tmp/01_chroot_init.sh /data/adb/service.d/01_chroot_init.sh;
  chmod 755 /data/adb/service.d/*.sh;
'"

Write-Host ">>> Host platform scripts successfully updated." -ForegroundColor Green
