# Self-Healing Network Watchdog (`01_net_watchdog`)

> **Role:** Continuous Layer 3 keepalive and routing table recovery daemon.  
> **Lifecycle:** Supervised by Root PM2 (`net-watchdog`).  
> **Log Buffer:** `/dev/shm/net-watchdog.log` (RAM tmpfs).

---

## 1. OPERATIONAL SPECIFICATION

* **Monitored Interface:** `wlan0`
* **Gateway Target:** `192.168.1.1` (Static ICMP ping every 45 seconds)
* **Failure Actions:**
  1. Re-asserts interface link state: `ip link set wlan0 up`
  2. Forces static IP: `ip addr replace 192.168.1.35/24 dev wlan0`
  3. Re-pins default route into routing `table main`: `ip route replace default via 192.168.1.1 dev wlan0 table main`
  4. Restores policy routing rule: `ip rule add from all lookup main pref 30000`