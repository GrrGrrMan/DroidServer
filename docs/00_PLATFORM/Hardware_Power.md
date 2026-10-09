# Power & Thermal Management (Sub-Tab: 00_PLATFORM)

> **Scope:** Universal power delivery architectures, software charging threshold control, battery health preservation, thermal dissipation standards, and electrical invariants for 24/7 Android servers.  
> **Blast Radius:** **CRITICAL**. Electrical or thermal faults cause hardware brownouts, battery swelling, PMIC latching, or permanent silicon shutdown.

---

## 1. THE TWO-TIER POWER ARCHITECTURE

Headless Android servers operate under one of two power architectures:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   Power Management Architecture                        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         ▼                                                     ▼
┌─────────────────────────────────┐   ┌───────────────────────────────────┐
│   TIER 1: SOFTWARE-CONTROLLED   │   │     TIER 2: PHYSICAL EMULATION    │
│        (Non-Invasive, Standard) │   │        (Dedicated Server Build)   │
├─────────────────────────────────┤   ├───────────────────────────────────┤
│ • OEM Battery Retained          │   │ • OEM Cell Desoldered             │
│ • Continuous USB-C Wall Power   │   │ • External 4.00V DC Buck Supply   │
│ • Charge Level Capped (60%-70%) │   │ • Zero Pouch Swelling Risk        │
│ • Direct Sysfs Ingestion:       │   │ • Detailed Case Study:            │
│   - charging_enabled = 0        │   │   [Oppo A91 Hardware Mod]         │
│   - battery_charging_enabled = 0│   │   (docs/hardware/oppo_a91.md)     │
└─────────────────────────────────┘   └───────────────────────────────────┘
```

---

## 2. TIER 1: SOFTWARE CHARGE LIMITING (RETAINED BATTERY)

For devices retaining their internal lithium-ion/polymer pouch cell:
* **The Hazard:** Holding a lithium cell at 100% state-of-charge ($4.35\text{V}–4.40\text{V}$) under 24/7 continuous wall power accelerates electrolyte decomposition and causes pouch swelling.
* **The Policy:** Bound charging between **60% and 70%** state-of-charge.
* **Kernel Sysfs Control Nodes:** The system identifies and toggles the kernel charging gate:
  ```bash
  # Common Android charge control sysfs interfaces:
  echo 0 > /sys/class/power_supply/battery/charging_enabled 2>/dev/null || true
  echo 0 > /sys/class/power_supply/battery/battery_charging_enabled 2>/dev/null || true
  echo 1 > /sys/class/power_supply/battery/store_mode 2>/dev/null || true
  ```
* Advanced users can deploy the Magisk/KernelSU module **ACC (Advanced Charging Controller)** to automate charging thresholds at the kernel level.

---

## 3. TIER 2: PHYSICAL DUMMY BATTERY CONVERSION

For dedicated server builds where the internal pouch cell is retired or removed:
* The cell is desoldered and replaced with a regulated DC buck converter tuned to **3.95V – 4.00V DC**.
* Detailed schematics, trimmer calibration procedures, BMS sleep-lockout recovery jumpering, and BootROM capture rules are documented in the **[Oppo A91 Case Study](../hardware/oppo_a91.md)**.

---

## 4. UNIVERSAL THERMAL MANAGEMENT STANDARDS

1. **Passive Convective Chimney:** Position the device vertically or elevated on nylon standoffs to promote unobstructed chimney airflow across chassis heat spreaders.
2. **Thermal Trip Thresholds:** ARM Cortex performance clusters begin throttling at $\approx 55^\circ\text{C} – 65^\circ\text{C}$ on mobile SoCs. Idle thermals should remain below $45^\circ\text{C}$.
3. **Telemetry Ingestion:** Thermal sensors are monitored directly via sysfs:
   ```bash
   cat /sys/class/thermal/thermal_zone*/temp
   ```

---

## 5. BACKFEED & POWER SEQUENCING RULES

When working with external DC power regulation:
* **$V_{\text{IN}} \ge 9.0\text{V}$ Before PC USB:** The external regulator must be powered on before connecting a workstation USB data cable to prevent reverse current from forward-biasing buck converter parasitic body diodes.
* **USB $V_{\text{BUS}}$ Integrity:** Do not physically cut the red 5V USB wire. Modern PMICs require an active $V_{\text{BUS}}$ signal on `VBUS_DET` to enable the USB PHY hardware and enumerate ADB or BootROM interfaces.