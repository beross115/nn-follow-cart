# nn-follow-cart

**"Alright, beltalowda. Time to build something that actually works."**  
— Naomi Nagata, Project Lead

## Project Overview

nn-follow-cart is a compact, autonomous skid-steer cart designed to follow its operator's smartphone using Bluetooth Low Energy (BLE) Received Signal Strength Indication (RSSI). The cart maintains a target distance of approximately 2 meters without relying on vision, LiDAR, or ultrasonic ranging as primary sensors. 

Core capabilities:
- **BLE RSSI-based following**: Phone acts as beacon; ESP32 continuously samples RSSI to estimate and close distance.
- **Skid-steer differential drive**: Two independently driven wheels for tight turns and zero-radius pivots.
- **Companion mobile app**: Cross-platform app for pairing, real-time telemetry (distance estimate, battery, status), manual override, and configuration.
- **Battery monitoring & safety**: Integrated voltage/current sensing with low-battery warnings, graceful shutdown, and over-discharge protection.
- **Open, hackable platform**: Built for rapid iteration on ESP32 (Arduino/ESP-IDF) with future expansion paths for neural network distance prediction or multi-phone handoff.

The project name honors Naomi Nagata's engineering pragmatism: simple, reliable, no drama.

## Goals

1. **Reliable 0–2 m following** in indoor/outdoor environments with <500 ms response latency.
2. **Phone-centric operation** — no extra beacons or tags required.
3. **Battery life** ≥ 2 hours of active following on a single charge with real-time monitoring.
4. **Safety first**: Immediate stop on signal loss, low battery, or manual kill-switch.
5. **Mobile app** delivering live RSSI, estimated distance, motor PWM, battery %, and OTA update support.
6. **Cost target** < $45 USD for core BOM (excluding 3D printing/fab).
7. **Extensibility**: Clear paths to add obstacle avoidance, path recording, or NN-based RSSI filtering.

## Recommended Approach

### Hardware Architecture
- **MCU**: ESP32-S3 (dual-core, BLE 5.0, plenty of GPIO, good ADC).
- **Drive**: Two 6V–12V geared DC motors + TB6612FNG or DRV8833 driver (better efficiency than L298N).
- **Chassis**: 3D-printed or laser-cut acrylic skid-steer frame with 2 driven wheels + 2 passive casters/omniwheels.
- **Power**: 2S LiPo (7.4V) with built-in BMS + buck converters (5V for motors/logic, 3.3V clean rail).
- **Sensing**: ESP32 ADC + voltage divider (or INA219/INA260 for coulomb counting). Optional cheap buzzer + status LEDs.
- **BLE**: Phone advertises a custom GATT service or uses manufacturer data; ESP32 scans or connects as central.

### Software Stack
- **Firmware**: ESP-IDF preferred for BLE stability and FreeRTOS task scheduling (separate tasks for BLE scanning, motor PID, telemetry). Fallback: Arduino-ESP32.
- **Distance estimation**: Initial implementation uses calibrated RSSI-to-distance curve (path-loss model). Future: lightweight neural net on ESP32 or offload to phone.
- **Control loop**: Simple proportional + derivative control on differential drive. Target RSSI window maps to forward speed; left/right RSSI bias (if using dual antennas or sequential sampling) for steering.
- **Mobile App**: Flutter (single codebase for iOS/Android). Uses `flutter_blue_plus` or `flutter_reactive_ble`. Features: device scan/pair, live dashboard, virtual joystick override, battery gauge, settings (target distance, max speed, calibration).
- **Safety & Comms**: Watchdog on BLE connection; if RSSI drops below threshold or connection lost for >3 s → full stop. App can send "halt" and "resume" commands.
- **Battery logic**: ADC sampling every 2 s, moving average, low-voltage cutoff at 6.0V (2S), app push notification + audible alert.
- **Future phases**: OTA via ESP32 HTTP update, data logging to SD or phone, optional IMU for dead-reckoning when RSSI is noisy.

### Development Phases
1. **Phase 0** (Kickoff): BOM finalization, chassis prototype, basic motor driver test.
2. **Phase 1**: BLE scanning + RSSI logging, basic forward/stop behavior.
3. **Phase 2**: Differential steering + PID tuning, phone app MVP.
4. **Phase 3**: Battery monitoring, safety interlocks, field testing.
5. **Phase 4**: Polish, documentation, neural-net distance model experiment.

No over-engineering. Get the cart moving first, then refine.

## Initial Bill of Materials (BOM)

| Component                  | Qty | Notes / Suggested Part                  | Est. Price (USD) |
|----------------------------|-----|-----------------------------------------|------------------|
| ESP32-S3 DevKit            | 1   | ESP32-S3-DevKitC-1 or NodeMCU-ESP32-S3  | $6–9            |
| Geared DC Motors (6–12V)   | 2   | 300 RPM, ~1 kg·cm torque, with encoders optional | $8–12     |
| Motor Driver               | 1   | TB6612FNG breakout (preferred) or DRV8833 | $3–5         |
| Chassis / Frame            | 1   | 3D print or 4 mm acrylic skid-steer kit | $5–15           |
| Wheels (driven)            | 2   | 65–80 mm rubber wheels with hubs        | $4–6            |
| Casters / Omniwheels       | 2   | 20–30 mm ball casters                   | $3–5            |
| 2S LiPo Battery            | 1   | 1000–2000 mAh, 25–40C, with XT30        | $8–12           |
| Battery BMS / Protection   | 1   | Integrated in pack or separate 2S BMS   | included        |
| Buck Converter (5V)        | 1   | MP1584 or LM2596 module                 | $1–2            |
| Voltage Divider / ADC      | 1   | 2x 10kΩ resistors + optional INA219     | $0.50–4         |
| Misc (wires, switch, headers, protoboard) | 1 | JST connectors, slide switch, LEDs, buzzer | $3–5       |
| **Total**                  | —   | —                                       | **~$40–70**     |

**Notes**:
- Phone: Any modern smartphone with BLE 4.0+ (iOS 13+ / Android 8+).
- Optional later: HC-SR04 or VL53L0X for obstacle stop, SD card module, small OLED.

## Repository Structure (Planned)

```
nn-follow-cart/
├── firmware/          # ESP32 PlatformIO + NimBLE (builds)
├── app/               # Flutter mobile app
├── dist/              # Release APK
├── docs/              # Pinout, BLE protocol, app testing
├── README.md
└── .github/           # CI
```

Let's get this thing built. Questions? Comments? Let's iterate.

**Status**: Phase 2 — Flutter app installable (APK in `dist/`). ESP32 firmware **scaffolded and builds** under `firmware/` (NimBLE peripheral `NN-CART`, motors, RSSI follow). Next: flash board, wire app to real GATT (drop simulation), floor-tune RSSI/motors.

*Project maintained under the Naomi Nagata "get it done" protocol. No excuses, just fixes.*
## Mobile App (Flutter)

Scaffolded in `app/`:

- **Core UI**: Live distance estimate (m), battery %, RSSI, status
- **BLE Foundation**: flutter_blue_plus with scan, connect, simulated telemetry (replace with real GATT)
- **FOLLOW ME**: Primary action button to toggle following mode (sends control command placeholder)
- **Permissions**: Bluetooth + Location handled
- **State**: Provider for reactive updates

See `docs/app/firebase-app-distribution.md` and `app/lib/main.dart` for implementation.

**To run**:
```bash
cd app
flutter pub get
flutter run
```
