#!/bin/bash
# log-guard.sh - Bounded memory guard protecting RAM tmpfs buffers (/dev/shm)
shopt -s nullglob
MAX_BYTES=5242880 # 5MB

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log guard active. Capping /dev/shm logs at 5MB."

while true; do
  sleep 60
  for log in /dev/shm/*.log /dev/shm/*.err; do
    [ -f "$log" ] || continue
    size=$(stat -c%s "$log" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_BYTES" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rotating $log ($size bytes > $MAX_BYTES)..."
      mv -f "$log.1" "$log.2" 2>/dev/null || true
      cp -f "$log" "$log.1" 2>/dev/null || true
      : > "$log"
    fi
  done
done