#!/bin/bash
GATEWAY="192.168.1.1"
STATIC_IP="192.168.1.35/24"
IFACE="wlan0"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Network watchdog active for $IFACE -> $GATEWAY"

while true; do
  sleep 45
  # Ping gateway with 2-second timeout
  if ! ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
    sleep 3
    # Double check before taking recovery action
    if ! ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway $GATEWAY unreachable! Restoring Layer 3 network..."
      
      # 1. Bring interface up and assert static IP
      ip link set "$IFACE" up 2>/dev/null
      ip addr replace "$STATIC_IP" dev "$IFACE" 2>/dev/null
      
      # 2. Restore default gateway in table main
      ip route replace default via "$GATEWAY" dev "$IFACE" table main 2>/dev/null
      ip rule add from all lookup main pref 30000 2>/dev/null || true
      
      # 3. Verify recovery
      if ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway connectivity successfully restored."
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway still unreachable. Will retry on next cycle."
      fi
    fi
  fi
done