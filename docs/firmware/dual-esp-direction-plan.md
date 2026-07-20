# Dual-ESP Direction Plan — nn-follow-cart

**Author:** Naomi  
**Date:** 2026-07-14  
**Status:** **Firmware implemented** (primary + secondary envs build). App dual-connect UI still optional.  
**Baseline now:** Primary BTS7960 `motorsSet(v±w)` + ESP-NOW stereo RX; secondary BLE ear + ESP-NOW TX. Protocol: `docs/firmware/ble-protocol.md`. Pins: `docs/pinout.md`, `docs/hardware/bts7960-pinout.md`. Build: `firmware/README.md`.

---

## Ben — short summary

- Single BLE link only gives **range**, not **bearing** → cart can’t steer toward the phone.
- Use **two ESP32s** left/right as a stereo RSSI baseline (not dual-antenna RF switch on one chip).
- **Primary (existing board):** motors + battery + phone GATT + fuse stereo + steer.
- **Secondary (new board):** second BLE ear; ships its RSSI samples to primary.
- **Direction signal:** ΔRSSI = RSSI_left − RSSI_right → turn bias (coarse heading, not precise angle).
- **Default stack:** keep phone as central; dual peripheral connections (or phone dual-central); **ESP-NOW** primary↔secondary; UART fallback on free GPIOs.
- **Place** antennas left/right, same height/orientation, **≥15–25 cm** baseline on chassis.
- **Ship in phases:** mock hardware → stereo log → steer → polish. Expect multipath noise; filter hard.
- **BOM delta:** ~one more ESP32-WROOM/devkit ($5–10) + 5V/GND + optional UART 3-wire.
- **Do not** flip whole BLE role (phone beacon / cart dual-central) until stereo-on-current-stack is proven.

---

## 1. Architecture options

### A — Dual antenna, one MCU (mention only)

| Item | Notes |
|------|--------|
| Idea | RF switch / two PCB antennas, time-multiplex RSSI on one radio |
| Pros | One board, one power domain, no inter-MCU protocol |
| Cons | Not simultaneous samples; switch + antenna design; still one radio; weak “stereo”; hardware redesign |
| Verdict | **Out of scope for Ben’s ask.** Revisit only if BOM/weight must stay at 1 MCU after stereo proves value |

### B — Two ESPs (focus)

| Variant | Description | Fit |
|---------|-------------|-----|
| **B1 Primary + Secondary ear** | Primary keeps current GATT + motors. Secondary measures phone RSSI and forwards samples to primary | **Recommended** |
| **B2 Dual equal peers** | Both talk to phone; either can drive motors | Extra complexity, dual motor owners = unsafe |
| **B3 Cart dual-central, phone beacon** | Both ESPs scan phone ads; no phone GATT required for sensing | Clean RF geometry, but **breaks** current working phone-central stack; defer |
| **B4 Phone-only stereo** | Phone dual-connects, computes ΔRSSI in Flutter, writes steer command | Great for **Phase 1 log / debug**; cart autonomy still wants on-cart fuse |

**Selected:** **B1**, with **B4 as a logging assist** in Phase 1. Keep B3 as optional Phase 3+ experiment if multipath kills connection-RSSI stereo.

---

## 2. Roles

### Primary ESP (`NN-Follow-Cart`) — existing board

| Responsibility | Detail |
|----------------|--------|
| Motors / TB6612 | Sole owner of STBY + PWM/DIR (safety: one brain) |
| Battery ADC | Unchanged |
| Phone GATT | Service/telemetry/control/config as today |
| Local RSSI | `ble_gap_conn_rssi` on phone connection → `rssi_p` (treat as **left** or **center-left**) |
| Fuse stereo | Combine `rssi_p` + secondary `rssi_s` → distance + turn bias |
| Follow loop | Extend from pure longitudinal to skid-steer: `v ± k·ΔRSSI` |
| Interlink master | ESP-NOW peer (or UART master); timeout → stop turn or full stop |

### Secondary ESP (`NN-Follow-Cart-S`) — new board

| Responsibility | Detail |
|----------------|--------|
| BLE ear only | No motor drivers |
| Phone path | **Preferred:** also GATT peripheral; phone maintains **second connection** so secondary gets connection RSSI of the same phone |
| Alt path | If dual-connect is painful: secondary scans phone advertisements (requires phone to advertise while connected — flaky on Android) |
| Sample publish | Stream `{rssi, t_ms, seq, quality}` to primary @ ~10–20 Hz |
| Identity | Distinct BLE name `NN-Follow-Cart-S` (still contains `NN-CART` if we want app to see both; or filter by MAC) |
| Failsafe | If no primary peer / no phone: idle, LED blink pattern |

### Who owns “truth”

- **Safety / motors:** primary only.
- **Range for stop-band / max range:** prefer primary RSSI (or min of both / average after calibration).
- **Bearing:** ΔRSSI after bias calibration (zero when phone dead-ahead).

---

## 3. How direction is derived

### Why one RSSI is not enough

Path-loss maps RSSI → approximate **distance**. Azimuth is unobservable on a single isotropic-ish sample. Lateral error needs a **spatial baseline**.

### Stereo ΔRSSI (primary method)

```
Δ = rssi_left_dBm - rssi_right_dBm   // after per-side offset calibration
// sign convention (recommend):
//   Δ > 0  → phone stronger on left  → turn left (positive left motor bias)
//   Δ < 0  → phone stronger on right → turn right
```

Map to skid-steer (extend current loop in `followControlLoop()`):

```
// longitudinal (existing idea)
err_d = d_est - TARGET_DIST_M
v = clamp(gain_d * err_d, -60..100)   // deadband DEADBAND_M

// lateral
Δ_f = lowpass(Δ - Δ_zero)             // Δ_zero from “phone ahead” cal
w = clamp(gain_w * Δ_f, -w_max..w_max)

left  = clamp(v - w)
right = clamp(v + w)
motorsSet(left, right)
```

**Distance estimate:** keep path-loss on **primary** RSSI first (stable with current telemetry). Optional: average d_left/d_right after per-antenna TxPower cal.

**Not** claiming true AOA degrees. At 2 m and 20 cm baseline, expect a **noisy left/right/center ternary** plus a soft bias — enough to pivot skid-steer toward the phone.

### Time sync

| Level | Need | Approach |
|-------|------|----------|
| Phase 1 log | Loose | Each side stamps `millis()`; phone or primary pairs by arrival / seq |
| Phase 2 steer | Samples within ~50–100 ms | Secondary sends `seq` + `t_ms`; primary drops samples older than 150 ms; no NTP |
| Optional later | Tighter | ESP-NOW ping RTT offset estimate; or shared GPIO pulse (overkill) |

Simultaneous connection RSSI is **not** phase-coherent; we only need **quasi-concurrent** power samples.

### Which radio sees the phone

| Mode | Primary | Secondary | Phone | Notes |
|------|---------|-----------|-------|-------|
| **M1 Dual peripheral (default)** | Peripheral + conn RSSI | Peripheral + conn RSSI | Dual-central: 2 connections | Matches current role model; Android multi-connect OK if we don’t thrash ads |
| **M2 Secondary scans ads** | Peripheral conn RSSI | Observer/scan | Must advertise | Avoid until M1 proven |
| **M3 Dual central cart** | Scan phone beacon | Scan phone beacon | Peripheral/beacon | Architecture flip — Phase 3+ |

**Default: M1.** Primary may stop its own advertising after connect (as today); secondary keeps its connection independently. App either:
- connects to both, or
- connects only to primary for control while secondary still accepts a second link from the same phone (if dual-connect implemented).

If Flutter dual-connect is painful short-term: **phone connects only to primary**; secondary gets RSSI by connecting **as central to a phone-side peripheral** — that needs app advertising. Prefer dual-central phone connecting to two cart peripherals.

### Phone-as-central vs cart dual-central

- **Keep phone central** for control/telemetry (working path: `docs/app/phone-debug-status.md`).
- Cart dual-central is a **research fork**, not the delivery path.

---

## 4. Wiring / physical placement

### Chassis geometry

```
        front of cart
    L-ESP ●------------● R-ESP     ← antennas elevated, same z
          |   baseline b ≥ 15–25 cm
          |      (prefer 20–30 cm if frame allows)
     [TB6612 + battery pack]
          Primary can be the L unit (motors wired to L board)
          Secondary is the R ear-only board
```

| Rule | Why |
|------|-----|
| Left/right baseline **≥ 15 cm**, target **20–30 cm** | ΔRSSI needs spatial leverage; sub-10 cm is mush |
| Same antenna orientation / height | Avoid systematic elevation bias |
| Clear of metal battery plate if possible | Multipath / shielding |
| Secondary **not** under the phone pocket | Body/pocket shadow already bad |
| Primary near motor driver | Short PWM/DIR leads, noise control |
| Common GND | ESP-NOW free-space or UART 3-wire |

### Primary pin budget (from `docs/pinout.md`)

Already used: PWM 25/26, DIR 14/27, STBY 4, BATT 36, LED 13, BUZZER 5, USB serial TX/RX.

**Free for interlink (pick one path):**

| Link | Pins (proposal) | Notes |
|------|-----------------|--------|
| ESP-NOW | none (Wi‑Fi radio) | **Default** — watch BLE+WiFi coexistence |
| UART2 | TX **GPIO17**, RX **GPIO16**, GND | Wired fallback; 115200 8N1; level 3.3 V |
| Optional link LED | GPIO21 | Secondary heartbeat visible |

Do **not** steal TB6612 pins. Do not use strapping pins for RX at boot without care (GPIO0 etc.).

### Power

- Share cart **5 V** rail (or USB 5 V) to both boards’ 5 V pins; common GND.
- Secondary current ~80–150 mA average with BLE; primary higher with motors separate on motor VBAT.
- Add bulk cap near secondary if long 5 V run.

---

## 5. Comms between ESPs

| Option | Pros | Cons | Use |
|--------|------|------|-----|
| **ESP-NOW** | No extra wires, low latency, simple payload, good for RSSI stream | Wi‑Fi radio on; coexistence with BLE; MAC pairing | **Recommend default** |
| **UART** | Deterministic, debug with logic analyzer, no Wi‑Fi | Cable, connector strain, pin use | **Fallback / Phase 0 mock** |
| **I2C** | Bus multi-drop | Secondary as master of async RSSI is awkward; clock stretch; less natural for “push samples” | Skip |

### Recommendation: ESP-NOW primary, UART as soldered backup

**ESP-NOW payload (v1, 12 bytes packed LE):**

| Offset | Type | Field |
|--------|------|--------|
| 0 | u8 | `magic` = `0xA5` |
| 1 | u8 | `ver` = 1 |
| 2 | u8 | `seq` |
| 3 | i8 | `rssi_dbm` |
| 4–7 | u32 | `t_ms` secondary millis |
| 8 | u8 | `flags` (bit0=phone_connected, bit1=signal_stale) |
| 9–11 | u8[3] | reserved / CRC8 |

Primary: if no valid secondary packet for **300 ms** while following → `w = 0` (drive straight on range only) and set telemetry flag; after **3 s** optional treat as degraded stereo (not full motor halt unless both RSSIs dead).

UART framing: same payload + `0x0D 0x0A` line or COBS; 115200.

**Pairing:** compile-time secondary MAC in primary `config.h`, or first-boot button learn (Phase 3).

---

## 6. Protocol changes (phone app / telemetry)

Keep **backward-compatible** path: existing 8-byte packet stays valid for old app builds.

### Option A — extend in place (tight)

Repurpose `seq` high bits / add status flags only — **not enough** for two RSSIs.

### Option B — Telemetry v2 (recommended)

New characteristic **or** longer notify on same UUID once app is updated:

| Offset | Type | Field |
|--------|------|--------|
| 0 | u8 | `ver` = 2 |
| 1 | i8 | `rssi_primary` |
| 2 | i8 | `rssi_secondary` |
| 3–4 | u16 | `distance_cm` |
| 5 | u8 | `battery` |
| 6 | u8 | `status` |
| 7 | i8 | `motor_left` |
| 8 | i8 | `motor_right` |
| 9 | i8 | `delta_rssi` (×1 dB, clamped) |
| 10 | i8 | `bearing_hint` (−100…100 turn command or filtered bias) |
| 11 | u8 | `seq` |

Until app lands v2: primary can still notify **v1 8-byte** with `rssi = rssi_primary` so today’s UI keeps working.

### New status bits (suggest)

| Bit | Mask | Meaning |
|-----|------|---------|
| 5 | `0x20` | `ST_STEREO_OK` — secondary sample fresh |
| 6 | `0x40` | `ST_STEREO_DEGRADED` — timeout / cal missing |

### Control / config

| Item | Change |
|------|--------|
| Control opcodes | Unchanged `STOP/FOLLOW/HALT` |
| Config | Keep target distance cm; optional second write: `steer_gain` u8, or separate config char later |
| App scan | List `NN-Follow-Cart` + optional `NN-Follow-Cart-S`; connect primary for control; optional second connect for phone-side RSSI debug |
| App UI | Show L/R RSSI, Δ, STEREO_OK; debug chart for Phase 1 |

### Phone dual-connect notes (Flutter / FBP)

- Connect primary first (motors/control).
- Connect secondary for stereo if using M1 phone-side verification.
- Do not require secondary for FOLLOW if primary has ESP-NOW stereo (app stays simple).
- Document MAC filter so user doesn’t pair the ear as the cart.

---

## 7. Phased delivery

### Phase 0 — Hardware mock (½–1 day)

- Mount second ESP32 on cart (breadboard OK).
- Common 5 V/GND; serial USB for both during bring-up.
- Flash secondary blink + ESP-NOW ping **or** UART loopback “hello”.
- Primary logs “secondary alive”.
- **Exit:** link uptime > 10 min, no brownouts when motors idle.

### Phase 1 — RSSI stereo log (1–2 days)

- Secondary: BLE peripheral + conn RSSI (or phone dual-connect) → ESP-NOW stream.
- Primary: fuse timestamps, Serial CSV: `t,rssi_p,rssi_s,delta,d_est`.
- Phone: optional dual-connect display; no motor change required (`motorsSet(v,v)` still).
- Walk phone L/R/front at ~2 m; capture logs.
- **Exit:** sign(Δ) matches side of phone ≥ ~80% in open room; identify zero-bias offset.

### Phase 2 — Steer (1–3 days)

- Implement `v ± w(Δ)` in `followControlLoop()` with deadbands.
- Safety: stereo timeout → w=0; signal lost → stop (existing).
- Floor tune: `gain_w`, clamp, low-pass (α≈0.2–0.3 @ 20 Hz).
- Telemetry v2 or debug Serial only first.
- **Exit:** cart pivots toward phone when operator steps left/right at ~2 m; no oscillation death-spin.

### Phase 3 — Polish

- App: L/R RSSI + stereo flag; drop dual-connect requirement if ESP-NOW solid.
- Calibration routine: “hold phone 2 m dead ahead → save Δ_zero”.
- Coexistence tuning (ESP-NOW duty vs BLE latency).
- Optional: phone-side bearing assist; optional B3 beacon experiment.
- Docs: update `ble-protocol.md`, pinout interlink section, firmware README.
- **Exit:** reliable FOLLOW ME in hallway/home; known failure modes documented.

---

## 8. Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Multipath** | Δ flips sign indoors | Low-pass, hysteresis, large deadband on w; test outdoors first |
| **Body / pocket block** | One side collapses | Antenna height; avoid blocking one ear; use min(RSSI) for “lost” |
| **BLE + Wi‑Fi coexistence** | ESP-NOW stalls, RSSI gaps | Limit ESP-NOW rate 10–20 Hz; UART fallback; measure notify jitter |
| **Sample desync** | Fake bearing | Drop stale >150 ms; never fuse cross-second samples |
| **Gain mismatch L/R radios** | Constant turn bias | Δ_zero calibration; per-side RSSI offset |
| **Dual Android connect flaky** | Secondary no RSSI | Prefer secondary→primary ESP-NOW with secondary’s own phone connection; or UART-only ear with secondary as peripheral always connected by phone |
| **Two motor owners** | Safety disaster | Secondary has **zero** motor pins |
| **Power sag** | Brownout on spin-up | Separate motor VBAT sense; bulk caps; common ground only |
| **Name confusion** | App connects to ear | Distinct name + primary-only control UUID ownership |
| **Overclaiming AOA** | Bad product expectations | Market as left/right assist, not compass heading |

---

## 9. BOM delta

| Item | Qty | Est. | Notes |
|------|-----|------|-------|
| ESP32-WROOM devkit (same family as current) | 1 | $5–10 | Match antenna type if possible |
| DuPont / JST wires | 1 set | $1–2 | 5V, GND, optional UART TX/RX |
| Mount / 3D print bracket | 1 | $0–3 | Elevate secondary antenna |
| Optional: 100–470 µF electrolytic on 5 V | 1–2 | $0.50 | Near each board |
| **Total delta** | | **~$7–15** | No second TB6612 |

Current cart BOM keeps single motor driver. No extra IMU required for this plan.

---

## 10. Recommended default path (why)

1. **Two ESP32s, primary + secondary ear (B1)** — answers Ben’s ask; keeps motor safety on one core.
2. **Keep phone = central, cart primary = GATT peripheral** — preserves working Flutter/NimBLE path (`NN-Follow-Cart`, 8-byte telemetry, FOLLOW/STOP/HALT).
3. **Secondary = second peripheral + connection RSSI → ESP-NOW → primary** — real spatial samples without RF switch hardware; wired UART if Wi‑Fi fights BLE.
4. **Direction = filtered ΔRSSI → skid-steer bias**, range still from path-loss on primary — minimal change to `followControlLoop()` structure.
5. **Baseline 20–30 cm left/right**, Phase 0→1→2→3 — prove link, prove sign(Δ), then steer, then app polish.
6. **Defer** dual-antenna one-MCU and full cart-central beacon flip until stereo RSSI shows value on the floor.

### Immediate next actions (when implementing)

1. Order/mount 2nd ESP32; wire 5V/GND.
2. Scaffold `firmware-secondary/` (or PlatformIO env `secondary`) — BLE peripheral + ESP-NOW TX only.
3. Primary: ESP-NOW RX + Serial CSV (no steer yet).
4. Capture Phase 1 logs with phone walking L/R.
5. Only then enable `w` term and app telemetry v2.

---

## Appendix A — Mapping to current code

| File | Today | Dual-ESP touch |
|------|-------|----------------|
| `firmware/src/main.cpp` | single RSSI, `motorsSet(speed,speed)` | fuse Δ; `motorsSet(v-w,v+w)`; ESP-NOW RX |
| `firmware/include/config.h` | pins, path-loss | secondary MAC, gains, UART pins, stereo timeouts |
| `firmware/include/telemetry.h` | 8-byte v1 | v2 struct or parallel publisher |
| `docs/firmware/ble-protocol.md` | v1 only | document v2 + stereo flags |
| `docs/pinout.md` | free GPIOs listed | document UART2 16/17 + power split |
| Flutter app | single device connect | optional second device; parse v2 |

## Appendix B — Explicit non-goals (this plan)

- Neural net bearing (future)
- True AOA / IQ samples / ESP32-C5 fancy RF
- Dual motor controllers
- Replacing BLE with UWB (interesting later, different BOM)

---

*Plan only. Implementation starts when Ben green-lights Phase 0 hardware.*
