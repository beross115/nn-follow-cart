# ESP32 Connectivity Report — nn-follow-cart

**Host:** this machine (Linux)  
**Date:** 2026-07-14  
**Port:** `/dev/ttyUSB0`  
**USB bridge:** Silicon Labs CP2102 (`10c4:ea60`, SER=0001, bus location 6-1)

## Summary table

| Check | Result | Notes |
|-------|--------|-------|
| USB link | **PASS** | `/dev/ttyUSB0` present; user in `dialout`; CP210x UART Bridge |
| Chip respond | **PASS** | esptool connects; ESP32-D0WD-V3 rev **v3.1** |
| Firmware alive | **PASS** | Clean boot serial: banner + `[BOOT] ready — waiting for phone` |
| BLE advertise string | **PASS** | `[BLE] advertising as NN-CART` (matches `NN_DEVICE_NAME`) |
| Rebuild | **PASS** | `pio run` in `firmware/` → SUCCESS (~4.6s, release) |

## Hardware / silicon

| Field | Value |
|-------|--------|
| Chip type | ESP32-D0WD-V3 |
| Revision | v3.1 |
| Features | Wi-Fi, BT, Dual Core + LP Core, 240 MHz |
| Crystal | 40 MHz |
| **MAC** | **f0:24:f9:0e:69:5c** |
| Flash | 4 MB (mfr `0x68`, device `0x4016`), 3.3 V strap |
| Serial adapter | CP2102 USB to UART Bridge Controller |

Commands used (esptool v5.2.0 via `esptool.py` on PATH):

```bash
esptool.py --port /dev/ttyUSB0 chip_id   # chip-id / MAC
esptool.py --port /dev/ttyUSB0 flash_id
esptool.py --port /dev/ttyUSB0 read_mac
```

`pio device list` also shows:

```
/dev/ttyUSB0  VID:PID=10C4:EA60 SER=0001  CP2102 USB to UART Bridge Controller
```

## Serial boot (115200, RTS/DTR EN pulse)

Clean capture after proper EN reset (DTR=GPIO0 high for run mode, RTS pulse on EN):

```
=== nn-follow-cart firmware ===
[BLE] advertising as NN-CART
[BOOT] ready — waiting for phone
```

Matches firmware:

- `firmware/include/config.h` → `#define NN_DEVICE_NAME "NN-CART"`
- `firmware/src/main.cpp` → NimBLE advertise + Serial prints

Note: an earlier capture that left RTS/DTR thrashing produced ROM bootloader spam (`try 0x400805e4` loop) before the app eventually ran. Always release RTS/DTR after open; do not hold EN low.

## PlatformIO build

```text
cd ~/code/nn-follow-cart/firmware && pio run
# PLATFORM: Espressif 32 (7.0.1) > ESP32 Dev Module
# RAM:   11.0% (36004 / 327680)
# Flash: 46.7% (612625 / 1310720)
# [SUCCESS] Took 4.59 seconds
```

Dep: NimBLE-Arduino @ 1.4.3

## Environment

- PATH helper: `export PATH="$HOME/development/pio-venv/bin:$PATH"`
- `pio` from `~/development/pio-venv/bin`
- System `esptool.py` (`~/.local/bin`); pio-venv python lacks esptool module (use CLI esptool instead)

## Verdict

**All five checks PASS.** Board on `/dev/ttyUSB0` is a healthy ESP32-D0WD-V3 (v3.1), MAC `f0:24:f9:0e:69:5c`, running nn-follow-cart firmware and advertising BLE as **NN-CART**; project rebuilds cleanly.
