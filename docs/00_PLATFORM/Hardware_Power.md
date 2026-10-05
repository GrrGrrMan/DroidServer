# Hardware_Power (Sub-Tab: 00_PLATFORM)

> **Scope:** DC power regulation, BMS dummy battery interface, thermal dissipation, mechanical chassis grounding, and backfeed prevention rules.  
> **Blast Radius:** **CRITICAL**. Electrical faults here cause immediate hardware shutdown, thermal throttling, PMIC damage, or permanent BROM lockout.

---

## 1. COMPONENT ARCHITECTURE & SPECIFICATIONS

| Stage | Component | Configuration / Specification |
| :--- | :--- | :--- |
| **Input Supply** | 18W QC / PD Wall Charger | Standard USB-C Power Delivery source (9V / 2A). |
| **Trigger Module** | QC/PD Decoy Board | Hardware DIP switches configured to negotiate fixed **9.00V DC**. |
| **Buck Regulator** | XL4015 5A Step-Down Module | Calibrated strictly to **3.95V – 4.00V DC** via onboard multi-turn trimmer. |
| **Transient Buffer** | 1000 µF Low-ESR Capacitor | Rated 10V–16V; wired directly across buck output screw terminals. |
| **Battery Emulator** | OEM Oppo A91 BMS Board | Desoldered from original pouch cell; 18–20 AWG twisted pigtails on `B+` / `B-`. |
| **Thermal Dissipation** | 14 × 14 × 6 mm Heatsinks | Finned anodized aluminum with 3M thermal tape; 15mm Kapton insulation. |

---

## 2. VOLTAGE CALIBRATION & OPERATIONAL BOUNDARIES

```text
[ 4.35V ] ─── Hard BMS Over-Voltage Protection (OVP) Cutoff ─── [FAULT LATCH]
    │
SAFE     ├─── 4.00V ─── Calibrated Idle Target (Upper Bound)
OPERATING├─── 3.95V ─── Calibrated Idle Target (Lower Bound)
RANGE    │
         └─── 3.70V ─── Minimum Acceptable Under A73 Core Burst
         │
[ 3.40V ] ─── MediaTek MT6358 PMIC Under-Voltage Lockout (UVLO) ─── [SHUTDOWN]
```

* **Target Calibration:**  
  Tune the multi-turn potentiometer on the XL4015 until the output measures strictly between **3.95V and 4.00V DC** on a calibrated digital multimeter before connecting the connector to the phone motherboard.  
* **Why not 4.20V+?**  
  Phone battery management and buck converter switching ripples occasionally induce minor voltage overshoot. Approaching 4.35V trips the onboard BMS OVP latch, instantly dropping output rail voltage to 0.00V.  
* **Why not below 3.70V?**  
  When all 4 Cortex-A73 performance cores burst under heavy workload (drawing 2.5A–3.5A transients), cable resistance and regulator response latency cause instantaneous voltage sag. Setting an idle voltage below 3.70V risks dipping below the **3.40V MT6358 PMIC UVLO threshold**, triggering brownout resets.  
* **Wiring Constraint:**  
  Keep the 18–20 AWG wire run between the buck terminals and BMS tabs **under 10 cm (5–8 cm recommended)** and lightly twist the positive (`B+`) and negative (`B-`) leads together to minimize loop inductance during transient load spikes.

---

## 3. BMS SLEEP-LOCKOUT RECOVERY (WAKING A TRIPPED BMS)

Severing the original lithium polymer pouch cell trips the BMS protection IC's internal under-voltage sleep state, turning off its low-side dual MOSFET gates. If the XL4015 output reads 4.00V but the battery connector outputs 0.00V:

1. Connect the buck converter output (4.00V DC) to the BMS `B+` (positive) and `B-` (negative) solder pads.  
2. Momentarily jump/short **`B-` (battery cell ground pad)** to **`P-` (pack output ground / connector shield)** using a pair of metal tweezers or a jumper wire for **1 second**.  
3. Remove the short.  
4. Measure voltage across the motherboard battery connector pins. The MOSFET gates will latch open, and the output rail will read a solid **4.00V DC**.

---

## 4. POWER SEQUENCING & REVERSE-CURRENT CHECKS

### A. The Backfeed Protection Rule

The XL4015 asynchronous buck converter features an internal high-side power switch with a parasitic body diode, and an external freewheeling catch diode connected in parallel between GND (anode) and the switch node (cathode).

* **When V_IN = 9.0V and V_BAT = 4.00V:**  
  The high-side body diode is reverse-biased by 5.0V (`V_IN - V_BAT`). Zero reverse current can flow backward into the 9V supply rail.  
* **When V_IN = 0.0V (Unplugged wall charger) and PC USB is connected:**  
  PC USB V_BUS (5.0V) powers phone logic and may backfeed the battery rail, forward-biasing the unpowered buck switch and causing component stress.

```text
MANDATORY POWER SEQUENCING:
Power-On:   Wall Charger ON (V_IN >= 9.0V) ───> Verify 4.00V ───> Plug PC USB Cable
Power-Off:  Unplug PC USB Cable ───> Unplug 18W Wall Charger
```

### B. USB $V_{\text{BUS}}$ Line Integrity

**DO NOT sever the red 5V wire inside the USB cable.**  
The MT6358 PMIC requires an active $V_{\text{BUS}}$ signal on the `VBUS_DET` ball to activate the hardware USB PHY pull-ups on $D+ / D-$. If $V_{\text{BUS}}$ is physically severed, MediaTek BROM mode, fastboot, and ADB communication will refuse to enumerate on the host PC.

---

## 5. MECHANICAL GROUNDING & THERMAL DISSIPATION

### A. The Vibration Motor Chassis Grounding Screw

The single silver chassis screw located directly above the coin vibration motor (`L2b A76`) must remain installed and torqued down.

* **Operational Reason:** This screw provides the mechanical downforce clamping the motherboard logic ground leaf springs onto the Volume Rocker flex pressure pads.  
* **Failure Mode:** If this screw is loose or removed, the Volume Up and Volume Down buttons will fail to register at the hardware level, eliminating the manual hardware interrupt required to capture MTK BROM mode.

### B. Thermal Management (Headless Server Deployment)

1. Remove all copper foil tape covering the MT6771 SoC and MT6358 PMIC EMI shielding cans.  
2. Apply 15mm Kapton insulating tape over all exposed motherboard SMD passives adjacent to the shields to eliminate contact short hazards.  
3. Affix 14 × 14 × 6 mm aluminum finned heatsinks directly atop the SoC (MT6771 + PoP LPDDR4X) and PMIC (MT6358) using thermally conductive adhesive tape.  
4. Position the motherboard vertically or elevated on nylon standoffs to enable unobstructed passive natural convection across the aluminum fins.

---

## 6. SILICON WARM-REBOOT & PMIC LATCHING INVARIANTS

### A. The Cold-Powerkey Latch Phenomenon

Empirical bootloader telemetry confirms that every recorded system boot on this hardware stack is `cold,powerkey`. The MediaTek MT6771 SoC and MT6358 PMIC cannot execute autonomous software warm-reboots over wireless sessions when running without a physical battery:

* **Silicon Root Cause:** On watchdog reset (`WDTRSTB_IN`) or software reboot (`reboot`, `sysrq-b`), the MT6358 PMIC collapses all buck and LDO regulators to 0V.  
* **Firmware Abort Gate:** During warm re-arm, MediaTek Little Kernel (LK) checks boot reason `BR_WDT_BY_PASS_PWK`. Because dynamic battery capacity is uncalibrated on the dummy BMS and external USB charging voltage is absent ($V_{\text{BUS}} = 0\text{V}$), LK detects an abnormal power state and executes `pmic_power_off()` to protect UFS storage from brownout corruption.  
* **Hardware Latch:** The MT6358 PMIC halts in a low-power shutdown state. It will **NOT** cycle back up until a physical ground pulse is applied to the power button (`cold,powerkey`).

### B. The No-Host-Reboot Invariant

* **NEVER** issue `reboot`, `reboot -f`, or `echo b > /proc/sysrq-trigger` across remote wireless shells. It will trigger immediate PMIC rail collapse and drop the headless machine permanently offline.  
* Maintenance and runtime updates must be conducted by soft-restarting the Debian container userland (`pkill -u oppo && /data/local/bin/chroot-debian.sh /usr/sbin/sshd`), never cycling the host Linux kernel or MediaTek silicon.

### C. Mains Power-Loss Recovery Constraints

Applying 4.00V to the battery pads after a mains blackout restores voltage to the rail, but does not assert a power-on trigger. The phone remains off until `PWRKEY` is asserted to ground.

#### Long-Term Autonomy Upgrades

1. **Mini-UPS Integration:** Install a 9V/12V DC router mini-UPS inline before the PD/QC decoy board to maintain uninterrupted rail uptime through mains cuts.  
2. **Parallel $V_{\text{BUS}}$ Tap:** Tap a secondary 5V step-down regulator from the same 9V input to feed the phone's USB-C port. This simultaneously asserts `VBUS_DET`, satisfying LK charger checks and enabling auto-boot on AC power restore.  
3. **RC Auto-Pulse Circuit:** Wire a small RC delay circuit (~22 µF + 100 kΩ) across the power button flex pads to deliver a simulated 1.5-second `PWRKEY` ground pulse whenever the 4.00V rail powers up.

### D. The 1% Battery & Fuel-Gauge Invariant (Cosmetic Counter Drift)

* **Observed Telemetry:** Fastfetch and kernel sysfs report `Battery: 1%` after $\approx 16\text{ hours}$ of continuous uptime.
* **Silicon Root Cause:** The MediaTek MT6358 fuel gauge tracks energy via Coulomb counting ($\int I \, dt$). Because power enters exclusively via dummy BMS tabs (`B+`/`B-`) rather than USB $V_{\text{BUS}}$, incoming charge current is absent. The counter steadily drains from its cold-boot OCV estimate ($\approx 80\%$ at $4.00\text{V}$) down to $0\text{ mAh}$, clamping sysfs capacity to `1%`.
* **Zero Throttling Confirmed:** All-core 100% stress testing confirmed the Cortex-A73 performance cluster sustains full $2.11\text{ GHz}$ ($2106000\text{ kHz}$) clocks regardless of the 1% reading. Frequency step-downs to $1.85\text{ GHz}$ under sustained multi-core load are governed strictly by MediaTek's native thermal cooling trip points (`mtktscpu` active trip points at $56^\circ\text{C} / 57^\circ\text{C}$), completely decoupled from battery state.
* **Zero Shutdown Risk:** Android's `BatteryService` is halted with Zygote (`ctl.stop zygote`), and the MT6358 hardware PMIC enforces shutdown solely on analog voltage ($V_{\text{BAT}} \le 3.40\text{V}$ UVLO).
* **Operational Invariant:** Treat `Battery: 1%` as a cosmetic artifact. Monitor electrical health exclusively via analog rail voltage (`/sys/class/power_supply/battery/voltage_now`), which must remain within $3.93\text{V} – 4.00\text{V DC}$.