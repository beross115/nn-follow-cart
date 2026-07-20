# Firmware (ESP32 dual-board)

Primary + secondary dual-ESP stereo RSSI + BTS7960 skid-steer.

## Layout

```
firmware/
  platformio.ini     # envs: primary | secondary | esp32dev (alias)
  include/           # config, motors, battery, telemetry, link_now
  src/
    main.cpp           # PRIMARY
    main_secondary.cpp # SECONDARY ear
    motors.cpp         # BTS7960 dual-PWM
    battery.cpp
    link_now.cpp       # ESP-NOW stereo stream
```

## Build

```bash
export PATH="$HOME/development/pio-venv/bin:$PATH"
cd ~/code/nn-follow-cart/firmware

pio run -e primary      # default
pio run -e secondary
```

## Flash

Primary (motors / existing board):

```bash
pio run -e primary -t upload --upload-port /dev/ttyUSB0
pio device monitor -e primary -b 115200
```

Secondary (new ear board — different USB port):

```bash
pio run -e secondary -t upload --upload-port /dev/ttyUSB1
pio device monitor -e secondary -b 115200
```

Boot markers:

- Primary: `=== nn-follow-cart PRIMARY ===` · `advertising as NN-Follow-Cart`
- Secondary: `=== nn-follow-cart SECONDARY (ear) ===` · `NN-Follow-Cart-S`
- Both log `[NOW] … MAC …` (channel 1 broadcast peer)

## Roles

| Board | BLE name | Motors | Phone | Interlink |
|-------|----------|--------|-------|-----------|
| **Primary** | `NN-Follow-Cart` | BTS7960 only | GATT control + telemetry | ESP-NOW **RX** |
| **Secondary** | `NN-Follow-Cart-S` | **none** | optional 2nd connect for conn RSSI | ESP-NOW **TX** ~20 Hz |

**Safety:** only primary drives EN/PWM. Ambiguous app connect → always pick **NN-Follow-Cart** (no `-S`) for FOLLOW/STOP.

## Stereo control

```
Δ = rssi_primary − rssi_secondary   # left − right after optional zero
left  = v − w(Δ)
right = v + w(Δ)
```

- Range from primary path-loss; turn off if stereo sample older than 300 ms (`w→0`).
- Telemetry status: `ST_STEREO_OK 0x20` / `ST_STEREO_DEGRADED 0x40` (v1 packet still 8 bytes).

Phone dual-connects: central ↔ primary **and** ↔ secondary so secondary gets connection RSSI. Control stays on primary only.

## Wiring

- BTS7960: `docs/hardware/bts7960-pinout.md`
- Dual-ESP plan: `docs/firmware/dual-esp-direction-plan.md`
- ESP-NOW needs shared 5 V/GND area only (no motor pins on secondary)

## Calibration knobs (`include/config.h`)

| Knob | Meaning |
|------|---------|
| `GAIN_DIST` / `GAIN_STEER` | longitudinal / ΔRSSI → speed |
| `STEER_DEAD_DB` / `STEER_MAX` | deadband + clamp |
| `RSSI_TX_1M` / `PATH_LOSS_N` | distance model |
| `MAX_SPEED` | BTS duty cap (of 255) |
| `LINK_NOW_CHANNEL` | Wi‑Fi channel for ESP-NOW (both boards must match) |

## Floor test order

1. Flash both; serial shows MACs + advertising.
2. Phone → **primary** only: FOLLOW when safe on stands.
3. Phone dual-connect secondary; primary log `stereo=1` and rising `nowRx`.
4. Walk phone left/right: `dF` sign should track side before trusting outdoor load.

## Next

- Optional UART fallback 16/17 if BLE+WiFi fights too hard
- Telemetry v2 (L/R RSSI extra fields)
- Soft-start ramping for cargo mass
- App: dual-connect helper + stereo flag UI
