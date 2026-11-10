#!/bin/bash
IFACE="wlan0"

get_active_gateway() {
  local gw
  gw=$(ip route show table all 2>/dev/null | grep "default via" | grep "$IFACE" | head -n 1 | awk '{print $3}')
  [ -z "$gw" ] && gw=$(getprop dhcp.${IFACE}.gateway 2>/dev/null)
  echo "$gw"
}

GW=$(get_active_gateway)
[ -z "$GW" ] && GW="192.168.1.1"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Network watchdog active for $IFACE (Target Gateway: $GW)"

IS_DOWN=0

while true; do
  sleep 45

  # 1. Guard against missing ping binary
  if ! command -v ping >/dev/null 2>&1; then
    if [ "$IS_DOWN" -eq 0 ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRIT] 'ping' binary missing. Watchdog paused."
      IS_DOWN=1
    fi
    sleep 300
    continue
  fi

  CURRENT_GW=$(get_active_gateway)
  [ -n "$CURRENT_GW" ] && GW="$CURRENT_GW"

  # 2. Probe Gateway
  if ! ping -c 1 -W 2 "$GW" >/dev/null 2>&1; then
    sleep 3
    # Secondary confirmation check to ignore transient jitter
    if ! ping -c 1 -W 2 "$GW" >/dev/null 2>&1; then
      # Only log if this is a fresh failure transition
      if [ "$IS_DOWN" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway $GW unreachable. Re-asserting Layer 3 route in table main..."
        IS_DOWN=1
      fi

      # Re-assert network stack
      ip link set "$IFACE" up 2>/dev/null
      ip route replace default via "$GW" dev "$IFACE" table main 2>/dev/null || true
      ip rule add from all lookup main pref 30000 2>/dev/null || true

      if ping -c 1 -W 2 "$GW" >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway connectivity successfully restored."
        IS_DOWN=0
      fi
    fi
  else
    # Link is healthy; recover state if we were previously down
    if [ "$IS_DOWN" -eq 1 ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway connectivity recovered."
      IS_DOWN=0
    fi
  fi
done