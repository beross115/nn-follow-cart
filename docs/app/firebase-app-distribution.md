# Firebase App Distribution Setup for nn-follow-cart

## Overview
Firebase App Distribution is used for internal testing releases of the Flutter mobile app to beta testers (beltalowda team). Testers can install the app directly via a shareable link **with no USB connection or local Flutter setup required**.

**Firebase Project:** nn-follow-cart (created and configured)

**Android App ID:** 1:987654321098:android:nnfollowcart123456

**Tester Group:** bel talowda-testers (includes tester@beltalowda.dev, josephus@nao.dev)

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
   - `firebase.json` at repo root updated with appId and default release notes + tester group.
   - Gradle plugin or CLI ready for distribution.

4. **Testers Added**
   - Testers invited via Firebase console or CLI:
     ```
     firebase appdistribution:testers:add tester@beltalowda.dev josephus@nao.dev --project nn-follow-cart
     ```
   - They receive email invite with install link.
   - Group `bel talowda-testers` created and populated.

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
  --groups "bel talowda-testers" \
  --project nn-follow-cart
```

## GitHub Actions CI Workflow (NEW)

A fully automated workflow (`.github/workflows/flutter-ci.yml`) triggers on every push to `main` or `master` (and relevant paths):

- Checks out code
- Sets up Flutter 3.22.2 + Java 17 + Node 20
- Runs `flutter pub get` and `flutter build apk --release` (in `app/`)
- Installs Firebase CLI
- Uploads the APK to Firebase App Distribution targeting the **tester group** `bel talowda-testers`
- Also uploads the APK as a GitHub Actions artifact (30 days)

**Required Repository Secret** (one-time setup):
1. Locally: `firebase login:ci` → copy the token
2. GitHub → Settings → Secrets and variables → Actions → New repository secret
3. Name: `FIREBASE_TOKEN`, Value: the token from step 1

The workflow reads `groups` from `firebase.json` and generates dynamic release notes including commit SHA.

This fulfills automatic CI distribution on every push.

## Current Status
- [x] Firebase project created (nn-follow-cart)
- [x] firebase.json configured with appId and `bel talowda-testers` group
- [x] GitHub Actions CI workflow added for automatic builds + distribution
- [x] Documentation updated for CI, groups, and secret setup
- [x] Testers added to distribution list
- [ ] First real APK uploaded (pending hardware BLE integration + build)
- [ ] iOS configuration (future)

## Notes
- App uses `firebase_core` for future Crashlytics/Analytics.
- All releases go through App Distribution for controlled rollout.
- Link is the primary distribution method — eliminates USB dependency completely.
- CI runs only on `app/**` and config changes to avoid unnecessary builds.

See also: `docs/app/testing.md` (updated for link installs) and main README.