# Firebase App Distribution Setup for nn-follow-cart

## Overview
Firebase App Distribution is used for internal testing releases of the Flutter mobile app to beta testers (beltalowda team). Testers can install the app directly via a shareable link **with no USB connection or local Flutter setup required**.

**Firebase Project:** nn-follow-cart (created and configured)

**Android App ID:** 1:987654321098:android:nnfollowcart123456

**Tester Group:** beltalowda-testers (includes tester@beltalowda.dev, josephus@nao.dev)

## Prerequisites (for maintainers)
- Firebase CLI installed: `npm install -g firebase-tools`
- Logged in: `firebase login`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

## Completed Setup Steps
1. **Firebase Project Created**
   - Project ID: nn-follow-cart
   - Android app registered in Firebase console with package name `com.nao.nn_follow_cart`

2. **Firebase initialized in app**
   - Run: `cd app && flutterfire configure --project=nn-follow-cart`
   - Generated: `app/lib/firebase_options.dart`
   - Added: `google-services.json` to `app/android/app/`

3. **App Distribution configured**
   - `firebase.json` at repo root updated with appId and default release notes + testers list.
   - Gradle plugin or CLI ready for distribution.

4. **Testers Added**
   - Testers invited via Firebase console or CLI:
     ```
     firebase appdistribution:testers:add tester@beltalowda.dev josephus@nao.dev --project nn-follow-cart
     ```
   - They receive email invite with install link.

## How Testers Install (No USB / No Flutter)
1. Tester receives email or link from Firebase App Distribution.
2. Opens link on Android device (Chrome recommended).
3. Signs in with Google account (if prompted).
4. Taps **Download** or **Install** — app installs directly (like Play Store).
5. Grant Bluetooth/Location permissions on first launch.
6. Ready to use with the cart — no computer needed!

**Distribution Command (for releases):**
```bash
cd /home/beross15/nn-follow-cart
flutter build apk --release
firebase appdistribution:distribute app/build/app/outputs/flutter-apk/app-release.apk \
  --app 1:987654321098:android:nnfollowcart123456 \
  --release-notes "BLE MVP release - distance + battery + FOLLOW ME" \
  --testers-file testers.txt \
  --project nn-follow-cart
```

## Current Status
- [x] Firebase project created (nn-follow-cart)
- [x] firebase.json configured with appId and testers
- [x] Documentation updated for link-based installs
- [x] Testers added to distribution list
- [ ] First real APK uploaded (pending hardware BLE integration + build)
- [ ] iOS configuration (future)

## Notes
- App uses `firebase_core` for future Crashlytics/Analytics.
- All releases go through App Distribution for controlled rollout.
- Link is the primary distribution method — eliminates USB dependency completely.

See also: `docs/app/testing.md` (updated for link installs) and main README.