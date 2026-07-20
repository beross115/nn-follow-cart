# Primary ESP32 ↔ Dual BTS7960 Pinout (cargo drive)

**Board:** custom ESP32 USB‑C (see `docs/pinout.md`)  
**Drivers:** 2× BTS7960 modules (one motor each) — e.g. KEA “43A” pair  
**Role:** **Primary** ESP only. Secondary stereo ear has **no** motor wiring.  
**Legacy:** TB6612 map is retired for cargo builds; light-bench TB6612 still documented at bottom.

---

## Why this map

Typical BTS7960 Arduino modules are **dual half-bridge**, not “PWM + DIR”:

| Signal | Function |
|--------|----------|
| **RPWM** | PWM for one direction (call this “forward”) |
| **LPWM** | PWM for the opposite direction (“reverse”) |
| **R_EN / L_EN** | Enable half-bridges (often tie both HIGH when active) |
| **VCC** | **5 V logic supply** (module MCU interface) |
| **GND** | Common with ESP + pack ground |
| **B+ / B−** | Motor battery (12 V class pack), **not** ESP 5 V |
| **M+ / M−** | Motor leads |
| **R_IS / L_IS** | Optional current sense (leave open or pull down if unused) |

Firmware ideally exposes `motorsSet(leftPct, rightPct)` (−100…100) by driving **exactly one** of RPWM/LPWM and holding the other at 0.

---

## ESP32 GPIO assignment (primary)

### Drive (BTS7960 × 2)

| Function | ESP32 GPIO | Silkscreen | BTS7960 module | Notes |
|----------|------------|------------|----------------|--------|
| Left forward PWM | **25** | P25 | **LEFT RPWM** | LEDC ch 0 |
| Left reverse PWM | **14** | P14 | **LEFT LPWM** | LEDC ch 2 |
| Right forward PWM | **26** | P26 | **RIGHT RPWM** | LEDC ch 1 |
| Right reverse PWM | **27** | P27 | **RIGHT LPWM** | LEDC ch 3 |
| Drivers enable | **4** | P4 | **R_EN + L_EN on BOTH modules** | HIGH = enabled; e-stop should also open B+ |

**Reuse of old TB6612 pins:**  
Left PWM/DIR → Left RPWM/LPWM; Right PWM/DIR → Right RPWM/LPWM; STBY → common EN. Cabling intent stays the same family of pins.

### Unchanged cart I/O

| Function | GPIO | Silkscreen |
|----------|------|------------|
| Battery ADC (divider) | 36 | SVP |
| Status LED | 13 | P13 |
| Buzzer | 5 | P5 |
| USB serial | 1 / 3 | TX / RX |

### Dual-ESP interlink (reserved — do not steal for motors)

| Function | GPIO | Notes |
|----------|------|--------|
| UART2 TX → secondary RX | **17** | P17 — fallback link |
| UART2 RX ← secondary TX | **16** | P16 |
| ESP-NOW | *(radio)* | no GPIO |
| Optional link LED | **21** | P21 |

### Free / optional later

| GPIO | Suggested use |
|------|----------------|
| 34, 35 | BTS7960 IS current sense (input-only ADC) via divider if  module puts out higher level |
| 32, 33 | Extra sensors / kill request |
| 18, 19, 22, 23 | SPI / spare |
| 0, 2, 12, 15 | Avoid for motors (boot/strapping / SD flash risk) |

**Do not use** SD0–SD3 / CLK for motor PWM unless you abandon onboard SD permanently.

---

## Module wiring (each BTS7960)

### Left motor module

```
ESP32                BTS7960 LEFT              Motor / pack
-----                ------------              ------------
P25  ──────────────► RPWM
P14  ──────────────► LPWM
P4   ──┬───────────► R_EN
       └───────────► L_EN
GND  ──────────────► GND  ──── shared pack GND
5V buck ───────────► VCC   (module logic; ~5 V — not motor power)

                     B+  ◄── fused 12 V pack +
                     B−  ◄── pack −
                     M+ / M− ──► left motor
                     R_IS / L_IS ── NC or to ADC later
```

### Right motor module

```
ESP32 P26 → RPWM
ESP32 P27 → LPWM
ESP32 P4  → R_EN + L_EN   (same enable net as left)
GND, 5V VCC, B+/B− same pack rails as left
M+/M− → right motor
```

### Pack / safety (required)

```
[LiFePO4 12.8V / 12V pack]
        |
   master kill switch
        |
   main fuse (e.g. 30–40 A)
        +------► B+ left BTS
        +------► B+ right BTS
   pack − ──────► B− both + ESP GND + buck GND

[separate buck 5V]
   pack → buck → ESP 5V pin (or USB path for bench)
                → both BTS7960 VCC
```

- **Never** feed B+ from ESP 5 V.  
- Motor wire **12–14 AWG**; logic DuPont OK.  
- Twisted M+/M− pairs; keep away from bare BLE antennas.  
- Heatsinks get **air**, not buried under ice-chest foam.

---

## Control truth table (each motor)

| Command | RPWM | LPWM | EN | Effect |
|---------|------|------|-----|--------|
| Forward `+pct` | PWM(duty) | 0 | 1 | Forward |
| Reverse `−pct` | 0 | PWM(duty) | 1 | Reverse |
| Coast stop | 0 | 0 | 1 | Freewheel-ish (module dependent) |
| Hard disable | x | x | 0 | Bridges off |
| E-stop | x | x | 0 **and** open B+ | Safe outdoor |

Duty: `duty = |pct| * MAX_SPEED / 100` with soft-ramp in firmware (heavy cart).

**Polarity:** if a side runs backward geometrically, swap that motor’s M+/M− **or** swap RPWM↔LPWM in software for that side only.

---

## LEDC channel plan (ESP32 classic)

| Channel | GPIO | Use |
|---------|------|-----|
| 0 | 25 | Left RPWM |
| 1 | 26 | Right RPWM |
| 2 | 14 | Left LPWM |
| 3 | 27 | Right LPWM |

Suggested: **20 kHz**, 8-bit (match current `config.h` motor PWM style) unless audible whine forces ~16–25 kHz experiment.

---

## Logic level notes

- ESP32 GPIO is **3.3 V**. Most BTS7960 breakout modules accept 3.3 V PWM/EN.  
- If a module’s EN never enables at 3.3 V, drive EN via a MOSFET/BJT or level shifter; PWM almost always works at 3.3 V.  
- Module **VCC** still wants **5 V** for the onboard electronics even when inputs are 3.3 V tolerant.

---

## Firmware mapping (`config.h` target)

```c
// BTS7960 dual-module cargo drive (primary ESP)
static const int PIN_RPWM_LEFT  = 25;
static const int PIN_LPWM_LEFT  = 14;
static const int PIN_RPWM_RIGHT = 26;
static const int PIN_LPWM_RIGHT = 27;
static const int PIN_MOT_EN     = 4;   // R_EN+L_EN both modules

// dual-ESP UART fallback (secondary ear)
static const int PIN_LINK_TX = 17;
static const int PIN_LINK_RX = 16;
```

`motors.cpp` migration: replace TB6612 DIR+single-PWM `applyOne` with dual-PWM apply; keep `motorsSet` / `motorsStop` / `motorsEnable` API unchanged for `main.cpp`.

---

## Bench bring-up checklist

1. No motors: EN low, flash firmware, confirm all four PWM pins idle 0.  
2. Logic only: EN high, slow 10% duty one direction, measure RPWM/LPWM with meter/scope.  
3. Jack stands: one wheel, fuse installed, verify forward/reverse per side.  
4. Soft-start ramp; kill switch cuts B+ under load test.  
5. Then mount secondary ESP (5 V/GND only).

---

## Legacy: TB6612 (light bench only)

| Function | GPIO |
|----------|------|
| PWM L/R | 25 / 26 |
| DIR L/R | 14 / 27 |
| STBY | 4 |

Do **not** use TB6612 with PowerWheels-class motors.

---

*Primary drive electrical contract for cargo nn-follow-cart. Stereo RSSI remains on second ESP + ESP-NOW/UART — no motor GPIOs there.*
