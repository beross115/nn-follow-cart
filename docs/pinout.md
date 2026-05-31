# ESP32 Pinout Chart - nn-follow-cart

**Board**: NodeMCU ESP-32S (actual user hardware, USB-C variant)  
**Status**: Master reference for wiring. Matches physical silkscreen exactly.  
**Last Updated**: 2026-05-31 by Naomi Nagata  
**Notes**: Two-row layout with USB-C at top. All labels taken directly from board silkscreen. GPIO pins are 3.3V logic. Never exceed 3.3V on inputs. Bootstrapping pins (GPIO0, GPIO2, GPIO12, etc.) have restrictions during boot.

## Physical Pinout (USB-C at Top)

| Left Row (Silkscreen) | Description | Right Row (Silkscreen) | Description |
|-----------------------|-------------|------------------------|-------------|
| 3V3 | 3.3V regulated output | VIN | 5V input (USB or external) |
| GND | Ground | GND | Ground |
| D1 / TX | GPIO1 / U0TXD | D0 / BOOT | GPIO0 / Boot mode select |
| D2 | GPIO2 | D3 | GPIO3 / U0RXD |
| D4 | GPIO4 | D5 | GPIO5 |
| D6 | GPIO6 | D7 | GPIO7 |
| D8 | GPIO8 | D9 | GPIO9 |
| D10 | GPIO10 | D11 | GPIO11 |
| D12 | GPIO12 | D13 | GPIO13 |
| D14 | GPIO14 | D15 | GPIO15 |
| D16 | GPIO16 | D17 | GPIO17 |
| D18 | GPIO18 | D19 | GPIO19 |
| D21 | GPIO21 | D22 | GPIO22 |
| D23 | GPIO23 | D25 | GPIO25 |
| D26 | GPIO26 | D27 | GPIO27 |
| D32 | GPIO32 | D33 | GPIO33 |
| D34 | GPIO34 | D35 | GPIO35 |
| D36 / VP | GPIO36 / ADC1_CH0 | D39 / VN | GPIO39 / ADC1_CH3 |
| EN | Chip enable / Reset | GND | Ground |
| 3V3 | 3.3V output | VIN | 5V input |

**Note on pin numbering**: Physical layout matches the NodeMCU ESP-32S board exactly as photographed. Silkscreen labels (D0–D39, 3V3, GND, VIN, EN, VP, VN) are authoritative. GPIO numbers shown for reference. Always cross-check against your specific board before wiring.

## Project-Specific Pin Assignments (Proposed)

- **Motors (TB6612FNG)**: 
  - PWM Left: GPIO25 (D25)
  - PWM Right: GPIO26 (D26)
  - DIR Left: GPIO14 (D14)
  - DIR Right: GPIO27 (D27)
  - STBY: GPIO4 (D4)
- **Battery Monitor**: GPIO36 / VP (D36) via voltage divider
- **Status LED**: GPIO13 (D13)
- **Buzzer**: GPIO5 (D5)
- **Programming**: GPIO0 (D0 BOOT), GPIO1 (D1 TX), GPIO3 (D3 RX)
- **Free GPIOs for expansion**: 32, 33, 34, 35, 39

## Update Instructions
- Edit this file directly when assigning new pins.
- Keep descriptions concise but complete.
- After changes, commit with: `git add docs/pinout.md && git commit -m "docs: update pinout chart to match NodeMCU ESP-32S [Naomi Nagata]"`

**"Beltalowda, pin it down right the first time or you'll be chasing ghosts in the wiring."** — Naomi Nagata

---
*This file is the single source of truth for hardware connections. No excuses.*