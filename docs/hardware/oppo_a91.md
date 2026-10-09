# Oppo A91 (CPH2021) Hardware Case Study

> **Scope:** Reference hardware implementation: physical DC buck conversion, OEM BMS dummy battery jumpering, MediaTek Helio P70 thermal design, and BootROM (BROM) recovery.  
> **Target Device:** Oppo A91 (`CPH2021`), MediaTek Helio P70 (`MT6771V`), MT6358 PMIC.

---

## 1. COMPONENT SPECIFICATIONS

| Component | Specification | Operational Role |
| :--- | :--- | :--- |
| **Input Supply** | 18W QC / PD USB-C | High-efficiency 9.00V DC input |
| **Trigger Module** | QC/PD Hardware Decoy | Fixed 9.00V negotiation |
| **Buck Regulator** | XL4015 5A Step-Down | Calibrated strictly to **3.95V – 4.00V DC** |
| **Buffer Capacitor**| 1000 µF Low-ESR (16V) | Absorbs instantaneous Cortex-A73 burst current |
| **Battery Emulator**| Desoldered OEM BMS | Retained protection IC circuit board |
| **Heatsinks** | 14 × 14 × 6 mm Aluminum | Finned passive heatsinks over SoC & PMIC shields |

---

## 2. VOLTAGE CALIBRATION & PMIC BOUNDARIES

```text
[ 4.35V ] ─── Hard BMS Over-Voltage Protection (OVP) Cutoff ─── [FAULT LATCH]
    │
SAFE│   ┌─── 4.00V ─── Calibrated Idle Target (Upper Bound)
ZONE│   └─── 3.95V ─── Calibrated Idle Target (Lower Bound)
    │
    └─── 3.70V ─── Minimum Under A73 Multi-Core Burst
    │
[ 3.40V ] ─── MediaTek MT6358 PMIC Under-Voltage Lockout (UVLO) ─── [SHUTDOWN]
```

* **POT Calibration:** Tune the XL4015 multi-turn trimmer until output reads **3.95V – 4.00V DC** before connecting to the motherboard.
* **Transient Lead Rule:** Keep wire runs between buck terminals and BMS solder tabs **under 10 cm (5–8 cm recommended)** using twisted 18–20 AWG wire.

---

## 3. BMS SLEEP-LOCKOUT RECOVERY (WAKING A SLEEPING BMS)

Severing the OEM pouch cell triggers the protection IC's internal UVLO latch. If the buck reads 4.00V but the motherboard battery connector outputs 0.00V:
1. Connect 4.00V DC to BMS tabs `B+` and `B-`.
2. Momentarily short **`B-` (cell negative pad)** to **`P-` (pack ground / shield)** with tweezers for **1 second**.
3. Release the short. The MOSFET gates will latch open, restoring 4.00V to the motherboard connector.

---

## 4. MECHANICAL GROUNDING & THERMAL CHIMNEY

* **Chassis Screw L2b A76:** The silver screw above the coin vibration motor MUST remain installed and torqued down. It mechanically clamps ground springs onto the volume rocker flex pads, required to capture MTK BROM.
* **Thermal Chimney:** Copper tape is removed from SoC/PMIC shielding cans. Finned heatsinks are mounted vertically atop the MT6771 (SoC) and MT6358 (PMIC) to allow passive convective natural airflow.

---

## 5. SILICON WARM-REBOOT LATCH (COLD-POWERKEY)

* **Silicon Root Cause:** On software reboot (`reboot`, `sysrq-b`), the MT6358 PMIC collapses rails to 0V. During re-arm, MediaTek Little Kernel checks `BR_WDT_BY_PASS_PWK`. Lacking USB $V_{\text{BUS}}$ charging current, LK detects abnormal power and triggers `pmic_power_off()` to protect UFS storage.
* **The No-Host-Reboot Invariant:** Never issue host kernel reboots across wireless sessions. Always soft-restart the Debian userland container (`pkill -u oppo && /data/local/bin/chroot-debian.sh /usr/sbin/sshd`).

---

## 6. DISASTER RECOVERY (MTK BROM)

If Android bootloader or partitions become corrupted:
1. Hold **Volume Up + Volume Down** simultaneously.
2. Connect PC USB cable (buck powered first: $V_{\text{IN}} \ge 9\text{V}$).
3. Interrogate BootROM via `mtkclient`:
   ```powershell
   python mtk printgpt
   python mtk w boot boot.img
   python mtk w vbmeta vbmeta.img.empty
   python mtk reset
   ```