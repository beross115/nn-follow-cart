# NN Follow Cart - Android App Testing Guide

**Target Device:** Samsung Galaxy S24 Ultra (Android 14 / One UI 6.1+)

**App:** Flutter-based companion app (`nn-follow-cart/app`)

**Prerequisites (Primary: Firebase App Distribution Link)**
- **Recommended:** Install via Firebase App Distribution link (no USB, no Flutter, no computer needed). See `firebase-app-distribution.md` for link and tester signup.
- Alternative (devs only): Flutter SDK + USB debugging for local builds.

**Link Install (No USB Required)**
1. Open the Firebase App Distribution link on your Android device.
2. Sign in and tap Install — app downloads and installs automatically.
3. Launch app, grant Bluetooth + Location permissions.
4. Proceed to testing sections below.

**Local USB Prerequisites (for developers)**
- Flutter SDK installed and `flutter doctor` clean (Android toolchain configured)
- Physical Samsung S24 Ultra connected via USB with USB debugging enabled
- App built and installed: `cd app && flutter run --release` (or debug)
- Hardware cart (ESP32) powered on and advertising as "NN-CART" (or any device with "NN-CART" in name for current scan filter)
- Location + Bluetooth permissions granted to the app on first launch

---

## 1. BLE Scanning & Device Discovery

**Goal:** Verify the app can scan for and list nearby BLE devices matching the cart.

### Steps
1. Launch the **NN Follow Cart** app on the S24 Ultra.
2. Grant Bluetooth Scan, Bluetooth Connect, and Location permissions when prompted.
3. On the dashboard, tap **SCAN FOR CART**.
   - Button label changes to **SCANNING...** and becomes disabled.
   - Scan runs for 10 seconds (hardcoded timeout).
4. Observe the "Nearby Carts" section populate with results.
   - Devices are filtered to those whose `platformName` contains "NN-CART" **or** advertise any service UUIDs.
   - Each entry shows device name (or MAC) and RSSI value.
5. Expected behavior on S24 Ultra:
   - Reliable discovery of ESP32 devices within ~10–15 m (line-of-sight).
   - RSSI values typically -40 dBm (very close) to -90 dBm (edge of range).
   - No crashes or permission errors on Android 14.

**Pass Criteria**
- Scan starts/stops cleanly.
- Relevant devices appear in list.
- Tapping "Connect" on a result initiates connection.

**Common Issues**
- No devices found → Ensure cart is powered and advertising. Check Android Bluetooth is enabled. Restart scan.
- Permission denied → Re-grant via Android Settings → Apps → NN Follow Cart → Permissions.

---

## 2. Connection & Telemetry (Distance Calculation & Battery Display)

**Goal:** Verify connection, simulated telemetry updates, distance estimation, and battery gauge.

### Steps
1. After scanning, tap **Connect** on a discovered cart device.
2. Verify status card updates:
   - Status changes from "Disconnected" → "Connected".
   - RSSI value appears and updates.
3. Watch the **Telemetry Row** (two cards side-by-side):
   - **DISTANCE card** (blue):
     - Icon: ruler/straighten
     - Value updates every ~2 seconds (simulated).
     - Shows value in meters (e.g., `1.8 m`, `2.2 m`) with one decimal place.
     - "Target: ~2.0 m" label visible.
   - **BATTERY card** (green):
     - Icon: battery_full
     - Percentage updates (simulated range: 85–95%).
     - Large bold percentage text.
     - Linear progress bar fills accordingly.
     - Color: green (>20%) or red (≤20%).
4. Distance calculation note (current implementation):
   - Currently **simulated** (placeholder): `1.8 + (millisecond % 400)/1000`.
   - Future real implementation: RSSI → distance model (path-loss equation) or NN inference.
   - Observe values fluctuate realistically around the 2.0 m target.

**Pass Criteria**
- Connection succeeds without errors.
- Both distance and battery values refresh live (every 2 s).
- Progress bar and color logic work correctly.
- No UI lag or overflow on S24 Ultra's large high-res screen.

**Verification Tips**
- Use Android's "Developer Options → Enable Bluetooth HCI snoop log" for advanced BLE debugging if needed.
- Check logcat for `flutter_blue_plus` messages.

---

## 3. FOLLOW ME Button Testing

**Goal:** Verify the core control button toggles following state, updates UI, and handles edge cases.

### Steps
1. Ensure the app is **connected** to a cart (from previous section).
2. Locate the large **FOLLOW ME** button (blue, play icon).
3. Tap **FOLLOW ME**:
   - Button immediately changes to:
     - Label: **STOP FOLLOWING**
     - Color: red
     - Icon: stop
   - Status card updates to **FOLLOWING** (green text).
   - `isFollowing` flag set to true.
4. Tap **STOP FOLLOWING**:
   - Reverts to **FOLLOW ME** (blue).
   - Status → **PAUSED** (orange text).
5. Edge case testing:
   - **Without connection**: Tap FOLLOW ME → SnackBar appears: "Connect to cart first".
   - **Disconnect while following**: Tap disconnect → status becomes "Disconnected", `isFollowing` auto-resets to false.
6. Observe console/logs (via `flutter logs` or Android Studio):
   - Message: `FOLLOW ME toggled: true/false`

**Pass Criteria**
- Button state, color, icon, and label update instantly.
- Status text color and value change correctly.
- No action possible without active connection.
- Clean state reset on disconnect.

**S24 Ultra Specific Notes**
- Large screen: Button is highly visible and easy to tap (24 px vertical padding).
- One-handed use friendly due to prominent placement.

---

## 4. Full End-to-End Test Scenario

1. Power on cart hardware.
2. Open app on S24 Ultra → grant permissions.
3. SCAN FOR CART → discover device → Connect.
4. Verify live distance (~2 m target) and battery % updating.
5. Tap FOLLOW ME → observe cart behavior (when real firmware connected).
6. Walk with phone → watch distance estimate change.
7. Tap STOP FOLLOWING.
8. Disconnect → confirm clean teardown.
9. Reconnect and repeat.

**Expected Overall Behavior**
- Smooth 60 fps UI on S24 Ultra.
- No permission or BLE crashes.
- Telemetry simulation demonstrates intended UX.

---

## 5. Known Limitations & Future Test Items (TODOs in code)

- Real BLE GATT service discovery and characteristic subscriptions (currently simulated).
- Actual RSSI-to-distance calculation (path loss model or ML).
- Sending control commands (0x01 = follow, 0x00 = stop) via GATT write.
- Real battery voltage from ESP32 ADC/INA sensor.
- Error handling for connection drops, low battery alerts.
- Virtual joystick override (future feature).

---

## Reporting Issues

When filing bugs, include:
- Device model + Android version (Samsung S24 Ultra, Android 14)
- App version / commit hash
- Steps to reproduce
- Screenshots or screen recordings of the dashboard
- Relevant logcat / flutter logs

**Document Owner:** Follow Cart Team  
**Last Updated:** 2026-05-31

This guide ensures consistent, repeatable testing of the core app features on the target hardware.