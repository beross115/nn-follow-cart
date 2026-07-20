# BLE Protocol — nn-follow-cart

**Device name:** `NN-Follow-Cart` (contains `NN-CART` for app scan filter)  
**Role:** ESP32 = GATT **peripheral** (advertises). Phone app = **central**.

## UUIDs

| Role | UUID |
|------|------|
| Service | `A1B2C3D4-E5F6-7890-ABCD-EF1234567890` |
| Telemetry (read + notify) | `A1B2C3D4-E5F6-7890-ABCD-EF1234567891` |
| Control (write) | `A1B2C3D4-E5F6-7890-ABCD-EF1234567892` |
| Config (read/write) | `A1B2C3D4-E5F6-7890-ABCD-EF1234567893` |

Defined in `firmware/include/config.h`.

## Telemetry packet (8 bytes, little-endian)

| Offset | Type | Field |
|--------|------|--------|
| 0 | int8 | `rssi` (dBm) |
| 1–2 | uint16 | `distance_cm` |
| 3 | uint8 | `battery_percent` 0–100 |
| 4 | uint8 | `status` flags |
| 5 | int8 | `motor_left` −100…100 |
| 6 | int8 | `motor_right` −100…100 |
| 7 | uint8 | `seq` |

### Status flags

| Bit | Mask | Meaning |
|-----|------|---------|
| 0 | `0x01` | FOLLOWING |
| 1 | `0x02` | CONNECTED |
| 2 | `0x04` | LOW_BATT (≤20%) |
| 3 | `0x08` | HALTED |
| 4 | `0x10` | SIGNAL_LOST (>3 s no RSSI) |
| 5 | `0x20` | STEREO_OK (secondary ESP-NOW sample fresh) |
| 6 | `0x40` | STEREO_DEGRADED (no fresh stereo — range-only drive) |

Notify interval ≈ 200 ms while connected.

### Dual-ESP names

| Device | BLE name | Role |
|--------|----------|------|
| Primary | `NN-Follow-Cart` | Motors + control + telemetry |
| Secondary | `NN-Follow-Cart-S` | Ear only; phone may second-connect for RSSI |

App **control/telemetry** must target **primary** only.

## Control (write 1 byte)

| Value | Name | Effect |
|-------|------|--------|
| `0x00` | STOP | Pause follow / exit manual, motors off |
| `0x01` | FOLLOW | Start FOLLOW ME (clears manual) |
| `0x02` | HALT | Emergency stop; needs FOLLOW to clear |
| `0x10` | DRIVE | Manual joystick: **3 bytes** `[0x10, left_i8, right_i8]` percent −100…100. Refreshed ~12 Hz while stick held. Firmware times out & stops after ~400 ms without packets. Preempts FOLLOW. |

Sign convention: positive = forward for that track. Arcade mix on phone → independent L/R.

## Config characteristic

- Read/write **uint16 LE** = target distance in **cm** (default 200).
- Firmware currently seeds default; full dynamic apply is Phase 2 polish.

## Distance model

```
d_m = 10 ^ ((TxPower_1m - RSSI) / (10 * n))
TxPower_1m = -59 dBm (calibrate)
n = 2.0
target = 2.0 m ± 0.25 m deadband
```

## App integration checklist

1. Scan filter: name contains `NN-CART` (already in app).
2. Connect → discover service UUID above.
3. Subscribe to telemetry notifications → parse 8-byte packet.
4. FOLLOW ME button → write `0x01` / `0x00` to control char.
5. Drop simulated telemetry once real notifies work.

## Safety

- Disconnect → motors stop, follow cleared, re-advertise.
- RSSI stale > 3 s while following → motors stop.
- Distance > 6 m → motors stop.
