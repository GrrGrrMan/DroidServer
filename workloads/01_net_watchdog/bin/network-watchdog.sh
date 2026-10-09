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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Network watchdog active for $IFACE (Initial Gateway: $GW)"

while true; do
  sleep 45
  CURRENT_GW=$(get_active_gateway)
  [ -n "$CURRENT_GW" ] && GW="$CURRENT_GW"

  if ! ping -c 1 -W 2 "$GW" >/dev/null 2>&1; then
    sleep 3
    if ! ping -c 1 -W 2 "$GW" >/dev/null 2>&1; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway $GW unreachable! Re-asserting Layer 3 route in table main..."
      ip link set "$IFACE" up 2>/dev/null
      ip route replace default via "$GW" dev "$IFACE" table main 2>/dev/null || true
      ip rule add from all lookup main pref 30000 2>/dev/null || true

      if ping -c 1 -W 2 "$GW" >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway connectivity successfully restored."
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway still unreachable. Will retry on next cycle."
      fi
    fi
  fi
done