$TARGET = "192.168.1.35:5555"
Write-Host ">>> Running Master Healthcheck on $TARGET..." -ForegroundColor Cyan

adb -s $TARGET shell "su -c '
  echo \"=== 1. PMIC & BATTERY RAIL ===\";
  dumpsys battery | grep -E \"voltage|level|status\";
  uptime;
  echo \"=== 2. MEMORY & HEADLESS STATE ===\";
  free -m;
  echo -n \"Zygote Status: \"; getprop init.svc.zygote;
  echo \"=== 3. CHROOT MOUNTS ===\";
  mount | grep \"/data/local/debian\" | wc -l | sed \"s/^/Active Mounts (Expect 7): /\";
  echo \"=== 4. LISTENING PORTS (HOST + CHROOT) ===\";
  netstat -tuln | grep -E \"LISTEN\";
'"
