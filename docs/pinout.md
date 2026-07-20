# ESP32 Pinout Chart - nn-follow-cart

**Board**: Custom ESP32 board with USB-C connector (actual user hardware photographed)  
**Status**: Master reference for wiring. Matches the provided photo exactly.  
**Last Updated**: 2026-07-20 by Naomi Nagata  
**Notes**: Two-column layout with USB-C at top (board rotated 180° vs older bottom-USB chart). All labels taken directly from board silkscreen. Includes dedicated SD card pins (SD0–SD3, CLK). GPIO pins are 3.3V logic.

Planned uses below match firmware `firmware/include/config.h` and the cargo BTS7960 map in [`docs/hardware/bts7960-pinout.md`](hardware/bts7960-pinout.md).

## Physical Pinout (USB-C at Top)

Viewed looking at the top of the board with **USB-C at the top**. Left/right are as you see them in that orientation (180° from the old USB-bottom chart).

| Left Row (Silkscreen) | Description | Planned use / function | Right Row (Silkscreen) | Description | Planned use / function |
|-----------------------|-------------|------------------------|------------------------|-------------|------------------------|
| CLK | SDMMC Clock | Keep free of motor wiring (onboard SD) | 5V | 5V input (USB or external) | Board 5 V in; BTS **logic VCC from separate 5 V buck** |
| SD0 | SDMMC Data 0 | Keep free of motor wiring (onboard SD) | GND | Ground | Common ground |
| SD1 | SDMMC Data 1 | Keep free of motor wiring (onboard SD) | SD3 | SDMMC Data 3 | Keep free of motor wiring (onboard SD) |
| P15 | GPIO15 | Avoid motors (strapping) — leave free | SD2 | SDMMC Data 2 | Keep free of motor wiring (onboard SD) |
| P2 | GPIO2 | Avoid motors (boot LED / strapping) — leave free | P13 | GPIO13 | **Status LED** (`PIN_STATUS_LED`) |
| P0 | GPIO0 (BOOT) | Boot strap / programming hold | GND | Ground | Common ground |
| P4 | GPIO4 | **Motor EN** — R_EN+L_EN on **both** BTS7960 modules | P12 | GPIO12 | Avoid motors (strapping / flash risk) — leave free |
| P16 | GPIO16 | Dual-ESP UART2 **RX** ← secondary TX (fallback link) | P14 | GPIO14 | **Left motor LPWM** (reverse PWM) → BTS LEFT LPWM |
| P17 | GPIO17 | Dual-ESP UART2 **TX** → secondary RX (fallback link) | P27 | GPIO27 | **Right motor LPWM** (reverse PWM) → BTS RIGHT LPWM |
| P5 | GPIO5 | **Buzzer** (`PIN_BUZZER`) | P26 | GPIO26 | **Right motor RPWM** (forward PWM) → BTS RIGHT RPWM |
| P18 | GPIO18 | Free / spare (SPI candidate) | P25 | GPIO25 | **Left motor RPWM** (forward PWM) → BTS LEFT RPWM |
| P19 | GPIO19 | Free / spare (SPI candidate) | P33 | GPIO33 | Free (extra sensor / kill request) |
| GND | Ground | Common ground | P32 | GPIO32 | Free (extra sensor / kill request) |
| P21 | GPIO21 | Optional dual-ESP **link LED** / heartbeat | P35 | GPIO35 | Free input-only ADC (optional BTS IS sense) |
| RX | GPIO3 / U0RXD | USB serial programming / logs | P34 | GPIO34 | Free input-only ADC (optional BTS IS sense) |
| TX | GPIO1 / U0TXD | USB serial programming / logs | SVN | GPIO39 / ADC1_CH3 | Free ADC input (optional sense later) |
| P22 | GPIO22 | Free / spare (SPI candidate) | SVP | GPIO36 / ADC1_CH0 | **Battery pack ADC** (`PIN_BATT_ADC`) via divider |
| P23 | GPIO23 | Free / spare (SPI candidate) | EN | Chip enable / Reset | Boot / reset button chain |
| GND | Ground | Common ground with pack division / motor modules | 3V3 | 3.3V regulated output | ESP rail only — **do not** power BTS7960 VCC from here |

**Note on pin numbering**: Table is **USB-C at top** (180° rotate of the older USB-bottom view — rows reversed **and** left/right swapped). Silkscreen labels are authoritative. SD0–SD3 + CLK are dedicated SDMMC pins. Always cross-check against your specific board before wiring.

## Project-Specific Pin Assignments

### Cargo drive (2× BTS7960) — **active for PowerWheels / 50 lb class**

Full write-up: [`docs/hardware/bts7960-pinout.md`](hardware/bts7960-pinout.md).

| Function | GPIO | Silkscreen | Module pin | Planned use / function |
|----------|------|------------|------------|------------------------|
| Left RPWM (fwd) | 25 | P25 | LEFT RPWM | Primary left drive forward PWM (LEDC) |
| Left LPWM (rev) | 14 | P14 | LEFT LPWM | Primary left drive reverse PWM (LEDC) |
| Right RPWM (fwd) | 26 | P26 | RIGHT RPWM | Primary right drive forward PWM (LEDC) |
| Right LPWM (rev) | 27 | P27 | RIGHT LPWM | Primary right drive reverse PWM (LEDC) |
| Motor EN (R_EN+L_EN both modules) | 4 | P4 | enable | Shared driver enable; LOW = coast/stop |
| Module logic VCC | — | — | **5 V buck**, not ESP 3V3 | BTS interface supply |
| Motor B+ / B− | — | — | **12 V pack**, fused + kill | Traction power (not ESP USB 5 V) |
| Battery Monitor | 36 | SVP | pack divider → ADC | Pack voltage telemetry / low-batt |
| Status LED | 13 | P13 | — | Connect / activity / fault blink |
| Buzzer | 5 | P5 | — | Alerts (low batt, signal lost) |
| Dual-ESP UART TX | 17 | P17 | → secondary RX | Fallback link if ESP-NOW flaky |
| Dual-ESP UART RX | 16 | P16 | ← secondary TX | Fallback link if ESP-NOW flaky |
| Optional link LED | 21 | P21 | secondary heartbeat | Stereo-link health indicator |
| Programming | 0 / 1 / 3 | P0 / TX / RX | boot + USB UART | Flash + serial debug |
| SD Card (SDMMC) | SD0–3, CLK | — | leave free of motor wiring | Future logging; not motor PWM |

### Legacy light-bench (TB6612FNG only)

- PWM L/R: 25 / 26 · DIR L/R: 14 / 27 · STBY: 4  
- **Not** rated for PowerWheels-class / cargo motors.

### Free GPIOs (after BTS + dual-ESP reserve)

P18, P19, P22, P23, P32, P33, P34, P35 (34/35 good for optional BTS IS current sense).

---

*This file is the single source of truth for hardware connections. No excuses.*
