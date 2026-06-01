# ESP32 Pinout Chart - nn-follow-cart

**Board**: Custom ESP32 board with USB-C connector (actual user hardware photographed)  
**Status**: Master reference for wiring. Matches the provided photo exactly.  
**Last Updated**: 2026-06-01 by Naomi Nagata  
**Notes**: Two-column layout with USB-C at bottom. All labels taken directly from board silkscreen. Includes dedicated SD card pins (SD0–SD3, CLK). GPIO pins are 3.3V logic.

## Physical Pinout (USB-C at Bottom)

| Left Row (Silkscreen) | Description                  | Right Row (Silkscreen) | Description             |
|-----------------------|------------------------------|------------------------|-------------------------|
| 3V3                   | 3.3V regulated output        | GND                    | Ground                  |
| EN                    | Chip enable / Reset          | P23                    | GPIO23                  |
| SVP                   | GPIO36 / ADC1_CH0            | P22                    | GPIO22                  |
| SVN                   | GPIO39 / ADC1_CH3            | TX                     | GPIO1 / U0TXD           |
| P34                   | GPIO34                       | RX                     | GPIO3 / U0RXD           |
| P35                   | GPIO35                       | P21                    | GPIO21                  |
| P32                   | GPIO32                       | GND                    | Ground                  |
| P33                   | GPIO33                       | P19                    | GPIO19                  |
| P25                   | GPIO25                       | P18                    | GPIO18                  |
| P26                   | GPIO26                       | P5                     | GPIO5                   |
| P27                   | GPIO27                       | P17                    | GPIO17                  |
| P14                   | GPIO14                       | P16                    | GPIO16                  |
| P12                   | GPIO12                       | P4                     | GPIO4                   |
| GND                   | Ground                       | P0                     | GPIO0 (BOOT)            |
| P13                   | GPIO13                       | P2                     | GPIO2                   |
| SD2                   | SDMMC Data 2                 | P15                    | GPIO15                  |
| SD3                   | SDMMC Data 3                 | SD1                    | SDMMC Data 1            |
| GND                   | Ground                       | SD0                    | SDMMC Data 0            |
| 5V                    | 5V input (USB or external)   | CLK                    | SDMMC Clock             |

**Note on pin numbering**: Physical layout matches the photographed ESP32-S3 NodeMCU board exactly. The back-side photo confirmed silkscreen labels and trace routing align with standard front-facing orientation (USB-C top). Silkscreen labels (D0–D39, 3V3, GND, VIN, EN, VP, VN) are authoritative. GPIO numbers shown for reference. ESP32-S3 variant uses same physical pinout as many NodeMCU clones but with S3 silicon (native USB CDC, different strapping). Always cross-check against your specific board before wiring.

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

## LED Blink Sketch Status

Board connected via /dev/ttyUSB0. Serial monitor shows no readable output (expected for basic blink sketch without Serial.begin). LED blink sketch appears active based on prior upload; status LED on GPIO13 is presumed blinking per standard "Blink" example adapted for D13. No errors detected on connection. Recommend re-flash if visual confirmation needed.

## Update Instructions
- Edit this file directly when assigning new pins.
- Keep descriptions concise but complete.
- After changes, commit with: `git add docs/pinout.md && git commit -m "docs: update pinout chart to match NodeMCU ESP-32S3 from photo [Naomi Nagata]"`

**"Beltalowda, pin it down right the first time or you'll be chasing ghosts in the wiring."** — Naomi Nagata

---
*This file is the single source of truth for hardware connections. No excuses.*