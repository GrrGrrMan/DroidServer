# Self-Healing Network Watchdog (`01_net_watchdog`)

> **Role:** Continuous Layer 3 keepalive and routing table recovery daemon.  
> **Lifecycle:** Supervised by Root PM2 (`net-watchdog`).  
> **Log Buffer:** `/dev/shm/net-watchdog.log` (RAM tmpfs).

---

## 1. OPERATIONAL SPECIFICATION

* **Monitored Interface:** `wlan0`
* **Gateway Target:** Dynamically resolved from Android routing tables (`ip route show table all`) and DHCP properties (`getprop dhcp.wlan0.gateway`), polled via ICMP every 45 seconds.
* **Failure Actions (Self-Healing):**
  1. Executes a secondary confirmation check after 3 seconds to avoid reacting to temporary Wi-Fi jitter.
  2. Re-asserts interface link state: `ip link set wlan0 up`
  3. Re-pins the discovered default route into routing `table main`: `ip route replace default via $GW dev wlan0 table main`
  4. Restores policy routing rule: `ip rule add from all lookup main pref 30000`