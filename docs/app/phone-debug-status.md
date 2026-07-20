# Phone debug status — Moto G 2025 (Ben)

Date: 2026-07-14 ~18:54 CDT  
Device: ZY32L7NGD5 (`moto_g___2025`)  
Package: `com.nao.nn_follow_cart`  
Cart MAC: `F0:24:F9:0E:69:5E` (public)  
ESP32 port: `/dev/ttyUSB0`

## Verdict

**CONNECTED: YES**

Fresh release APK + open-bond firmware + bond wipe path fixed the Moto G failure
(`PlatformException(requestMtu, device is disconnected)` from stale LE bond + FBP auto-MTU race).

## PASS / FAIL table

| Step | Result | Evidence |
|------|--------|----------|
| PATH / toolchains | PASS | adb, flutter, java, pio on PATH |
| `flutter analyze` | PASS | No issues found |
| Connect-path source fixes present | PASS | `removeBond`, `mtu: null`, 3x connect retry, post-GATT `requestMtu(185)` |
| Firmware open bond + MTU 185 | PASS | `setSecurityAuth(false,false,false)`, `setMTU(185)`, `stopAdvertising` on connect |
| Build release APK | PASS | `app-release.apk` → `dist/nn-follow-cart.apk` mtime **2026-07-14 18:52** (was stale 18:40) |
| Flash firmware `/dev/ttyUSB0` | PASS | pio upload SUCCESS; serial: `[BLE] advertising as NN-Follow-Cart` |
| Unbond cart | PASS | dumpsys bond events: `btif_dm_remove_bond` → `BOND_STATE_NONE` at 18:51:33; app also best-effort `removeBond` |
| `adb install -r` dist APK | PASS | Streamed Install Success |
| Grant BT_SCAN / BT_CONNECT / FINE / COARSE | PASS | all `granted=true` |
| Force-stop + launch | PASS | MainActivity resumed |
| SCAN finds cart | PASS | Carts list: `NN-Follow-Cart` RSSI ~-30, id `F0:24:F9:0E:69:5E` |
| Connect + GATT discover | PASS | `onClientConnectionState connected=true`; `onSearchComplete status=0` |
| Telemetry notify | PASS | notify on `…7891`; UI distance/RSSI update (live) |
| MTU 185 (post-GATT) | PASS | `configureMTU mtu=185` → `onConfigureMTU mtu=185 status=0` (no disconnect) |
| UI shows Connected | PASS | Screenshot: STATUS **Connected**, “Connected to cart — real telemetry”, RSSI live |
| Overall connect for Ben | **PASS** | End-to-end on Moto G 2025 |

Artifacts:
- `docs/app/phone-debug-ui-connected.png`
- `docs/app/phone-debug-ui-connected-2.png`
- `docs/app/phone-debug-logcat-gatt.txt`
- APK: `dist/nn-follow-cart.apk` (18:52, not the old 18:40 build)

## Root cause (resolved)

1. **Stale Android LE bond** (`ble_enc_key_size=0` / prior failed pairing) caused the link to drop right after connect.
2. **flutter_blue_plus default auto `requestMtu(512)`** raced that drop → `PlatformException(requestMtu, device is disconnected)`.
3. **Stale installed APK** (dist still 18:40) meant Ben never received the app-side fix until this rebuild.

## Fixes shipped in this run

App (`app/lib/main.dart`):
- Best-effort `removeBond` before connect (and after first failed attempt)
- `device.connect(..., mtu: null)` to disable FBP auto-MTU
- 3 connect retries with backoff
- Optional `requestMtu(185)` only after services + notify are up, guarded by `isConnected`

Firmware (`firmware/src/main.cpp`):
- `NimBLEDevice::setSecurityAuth(false, false, false)` (open / no-bond)
- `setMTU(185)`
- `stopAdvertising()` on connect; re-advertise on disconnect

## What Ben should tap

1. Open **NN Follow Cart** (already installed with the 18:52 build).
2. Tap **SCAN FOR CART**.
3. When **NN-Follow-Cart** appears, tap **Connect**.
4. Wait until STATUS shows **Connected** and “Connected to cart — real telemetry”.
5. Tap **FOLLOW ME** when ready.

### If Connect fails again (rare)

Human system Bluetooth cleanup:
1. Phone **Settings → Connected devices / Bluetooth**.
2. Find **NN-Follow-Cart** (or unknown LE device matching the cart).
3. **Forget / Unpair**.
4. Leave system Bluetooth settings (do not stay on the device detail page).
5. Power-cycle the cart (USB unplug/replug or EN button).
6. Re-open the app → **SCAN FOR CART** → **Connect**.

Do **not** pair the cart from system Bluetooth settings; use only the app.

## Notes

- UiAutomator a11y dumps stayed stale during Flutter animations (`could not get idle state`); screenshots + BluetoothGatt logcat are the source of truth for this run.
- Bonded devices list empty after wipe; connection is open (NOT_BONDED) which is intentional for this peripheral.
