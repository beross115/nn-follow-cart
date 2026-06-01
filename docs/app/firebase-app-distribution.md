# Firebase App Distribution Setup for nn-follow-cart

## Overview
Firebase App Distribution is used for internal testing releases of the Flutter mobile app to beta testers (beltalowda team).

## Prerequisites
- Firebase project created (console.firebase.google.com)
- FlutterFire CLI installed: `dart pub global activate flutterfire_cli`
- Firebase CLI: `npm install -g firebase-tools`

## Setup Steps

1. **Initialize Firebase in project**
   ```bash
   cd app
   flutterfire configure --project=nn-follow-cart
   ```
   This generates `lib/firebase_options.dart` and updates Android/iOS configs.

2. **Add App Distribution dependencies**
   Already in pubspec.yaml: firebase_core

3. **Configure App Distribution (firebase.json)**
   Create at repo root or app/:

4. **Build & Distribute**
   ```bash
   flutter build apk --release
   firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
     --app 1:1234567890:android:abc123 \
     --release-notes "Initial BLE MVP with distance + battery telemetry" \
     --testers "naomi@beltalowda.dev,amos@nao.dev"
   ```

## Current Status (as of scaffolding)
- [x] pubspec.yaml includes firebase_core
- [x] Basic app structure ready for `flutterfire configure`
- [ ] firebase.json not yet generated (run configure when Firebase project ready)
- [ ] google-services.json / GoogleService-Info.plist pending

## BLE + Telemetry Notes
The app foundation uses flutter_blue_plus. Future integration:
- Custom GATT service for RSSI telemetry from ESP32
- Characteristics: Distance (float), Battery (uint8), Control (follow/stop)

See lib/main.dart for current implementation skeleton.

Next: Run actual device tests once hardware BLE is broadcasting.
