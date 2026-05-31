# ESP32 Pinout Chart - nn-follow-cart

**Board**: ESP32 DevKit (ESP32-D0WD-V3) - 30-pin or 38-pin DevKitC variant  
**Status**: Master reference for wiring. Update this file as pin assignments are finalized.  
**Last Updated**: 2026-05-31 by Naomi Nagata  
**Notes**: All pins listed for completeness. GPIO pins are 3.3V logic. Never exceed 3.3V on inputs. Bootstrapping pins (GPIO0, GPIO2, GPIO12, etc.) have restrictions during boot.

## Pinout Table

| Physical Pin | GPIO | Label | Type | Description | Project Assignment / Notes |
|--------------|------|-------|------|-------------|----------------------------|
| 1 | 3V3 | 3V3 | Power | 3.3V regulated output (max ~500mA) | Logic power rail |
| 2 | EN | EN | Input | Chip enable / Reset (active low) | Pull high or to reset button |
| 3 | 36 | VP / GPIO36 | ADC | ADC1_CH0, input only | Battery voltage sense (via divider) |
| 4 | 39 | VN / GPIO39 | ADC | ADC1_CH3, input only | Optional current sense |
| 5 | 34 | GPIO34 | ADC | ADC1_CH6, input only | Free / future sensor |
| 6 | 35 | GPIO35 | ADC | ADC1_CH7, input only | Free / future sensor |
| 7 | 32 | GPIO32 | ADC/TOUCH | ADC1_CH4, Touch9 | Motor driver PWM or LED |
| 8 | 33 | GPIO33 | ADC/TOUCH | ADC1_CH5, Touch8 | Motor driver PWM or LED |
| 9 | 25 | GPIO25 | ADC/TOUCH | ADC2_CH8, Touch6, DAC1 | Left motor PWM (TB6612) |
| 10 | 26 | GPIO26 | ADC/TOUCH | ADC2_CH9, Touch7, DAC2 | Right motor PWM (TB6612) |
| 11 | 27 | GPIO27 | ADC/TOUCH | ADC2_CH7, Touch7 | Motor direction / enable |
| 12 | 14 | GPIO14 | ADC/TOUCH | ADC2_CH6, Touch6, HSPI | Motor direction pin A |
| 13 | 12 | GPIO12 | ADC/TOUCH | ADC2_CH5, Touch5, HSPI | Bootstrapping - avoid during flash |
| 14 | GND | GND | Power | Ground | Common ground |
| 15 | 13 | GPIO13 | ADC/TOUCH | ADC2_CH4, Touch4, HSPI | Status LED (built-in on many boards) |
| 16 | 9 | GPIO9 | - | Flash D2 (internal) | Do not use |
| 17 | 10 | GPIO10 | - | Flash D3 (internal) | Do not use |
| 18 | 11 | GPIO11 | - | Flash CMD (internal) | Do not use |
| 19 | 6 | GPIO6 | - | Flash CLK (internal) | Do not use |
| 20 | 7 | GPIO7 | - | Flash D0 (internal) | Do not use |
| 21 | 8 | GPIO8 | - | Flash D1 (internal) | Do not use |
| 22 | 5 | GPIO5 | ADC/TOUCH | ADC2_CH0, Touch5, VSPI | Buzzer or status LED |
| 23 | 3 | GPIO3 | ADC/UART | ADC2_CH1, Touch3, U0RXD | UART0 RX (programming) |
| 24 | 4 | GPIO4 | ADC/TOUCH | ADC2_CH2, Touch4, HSPI | Motor driver STBY or enable |
| 25 | 2 | GPIO2 | ADC/TOUCH | ADC2_CH3, Touch2, HSPI | Bootstrapping - avoid high on boot |
| 26 | 0 | GPIO0 | ADC/TOUCH | ADC2_CH1, Touch1, Boot | Boot mode select (pull low for flash) |
| 27 | 1 | GPIO1 | ADC/UART | ADC1_CH0? Wait, U0TXD | UART0 TX (programming) |
| 28 | 8? Wait standard  | - | - | - | See board silkscreen |
| 29 | 3V3 | 3V3 | Power | 3.3V | Duplicate power |
| 30 | GND | GND | Power | Ground | Duplicate ground |
| VIN | VIN | VIN | Power | 5V+ input (USB or external) | Main power input (5V from USB or buck) |
| GND | GND | GND | Power | Ground | Multiple grounds available |

**Note on pin numbering**: Physical pin numbers are approximate for common 30-pin DevKit boards. Always verify against your specific board's silkscreen and schematic. GPIO numbers are authoritative.

## Project-Specific Pin Assignments (Proposed)

- **Motors (TB6612FNG)**: 
  - PWM Left: GPIO25
  - PWM Right: GPIO26
  - DIR Left: GPIO14
  - DIR Right: GPIO27
  - STBY: GPIO4
- **Battery Monitor**: GPIO36 (VP) via voltage divider (e.g., 10k/10k for 2S)
- **Status LED**: GPIO13 (or onboard LED if present)
- **Buzzer**: GPIO5
- **Programming**: GPIO0 (BOOT), GPIO1 (TX), GPIO3 (RX)
- **Free GPIOs for expansion**: 32, 33, 34, 35, 39

## Update Instructions
- Edit this file directly when assigning new pins.
- Keep descriptions concise but complete.
- Add a new row for any custom board variant.
- After changes, commit with: `git add docs/pinout.md && git commit -m "docs: update pinout chart [Naomi Nagata]"`

**"Beltalowda, pin it down right the first time or you'll be chasing ghosts in the wiring."** — Naomi Nagata

---
*This file is the single source of truth for hardware connections. No excuses.*