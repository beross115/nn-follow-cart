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

**Note on pin numbering**: Physical layout matches the provided photo exactly. Silkscreen labels are authoritative. SD0–SD3 + CLK are dedicated SDMMC pins. Always cross-check against your specific board before wiring.

## Project-Specific Pin Assignments (Proposed)

- **Motors (TB6612FNG)**: 
  - PWM Left: GPIO25 (P25)
  - PWM Right: GPIO26 (P26)
  - DIR Left: GPIO14 (P14)
  - DIR Right: GPIO27 (P27)
  - STBY: GPIO4 (P4)
- **Battery Monitor**: GPIO36 / SVP (SVP) via voltage divider
- **Status LED**: GPIO13 (P13)
- **Buzzer**: GPIO5 (P5)
- **Programming**: GPIO0 (P0), TX (TX), RX (RX)
- **SD Card (SDMMC)**: SD0, SD1, SD2, SD3, CLK
- **Free GPIOs for expansion**: P21, P22, P23, P16, P17, P18, P19, P32, P33, P34, P35

---

*This file is the single source of truth for hardware connections. No excuses.*