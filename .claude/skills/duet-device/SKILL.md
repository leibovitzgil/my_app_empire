---
name: duet-device
description: Run the Duet app on a physical iOS device (iPhone/iPad) wired to the local Firebase emulators. Use when asked to run Duet on a real device/iPad/iPhone, test on hardware against Auth+Firestore, or debug device-only behaviour (push, camera, real gestures) with the emulator backend.
---

# Run Duet on a real iOS device against the local emulators

`duet-emulator` (and `dev.sh`) target web / desktop / the iOS **simulator** —
all of which share the host's loopback, so `127.0.0.1` just works. A **physical
device is a different machine on the network**: `127.0.0.1` there is the device
itself, so it can't see emulators running on your Mac. This skill bridges that
gap.

## Run it

```bash
cd apps/duet
./dev_device.sh                 # first connected physical iOS device
./dev_device.sh <device-id>     # a specific device (see `fvm flutter devices`)
```

`dev_device.sh` finds your Mac's LAN IP, starts the emulators bound to
`0.0.0.0` and seeded (reusing `dev.sh --emulators-only`), waits until both
answer on that LAN IP, then runs the app with
`--dart-define=EMU_HOST=<LAN IP>` so Firebase Auth + Firestore dial your Mac
across the network. Sign in with `you@duet.dev` / `password` (invite
`friend@duet.dev`). Quitting the app (`q`) also stops the emulators.

Force the host IP (e.g. multiple interfaces / VPN) with
`EMU_HOST=192.168.1.20 ./dev_device.sh`.

## How the pieces fit

- **`lib/main_emulator.dart`** reads the emulator host from
  `String.fromEnvironment('EMU_HOST', defaultValue: '127.0.0.1')`, so the
  simulator/web flow is unchanged and only the device flow overrides it.
- **`firebase.json`** binds the emulators — Auth (`:9099`), Firestore
  (`:8080`), Functions (`:5001`), Storage (`:9199`) — to `0.0.0.0` (not
  `127.0.0.1`) so other devices on the LAN can reach them.
- **`fvm flutter`** is used because the workspace pins the SDK via FVM
  (`.fvmrc` / `.fvm/`). A mismatched global `flutter` fails `pub get`
  (`very_good_analysis` needs a newer Dart).

## One-time iOS setup (per fresh `ios/` scaffold)

`apps/duet/ios/` is git-ignored and generated. If it's missing/incomplete,
regenerate: `fvm flutter create --platforms=ios --project-name duet .`. Then,
for a real-device + Firebase build:

1. **Deployment target ≥ 15.0** (`cloud_firestore` requires it) — set
   `platform :ios, '15.0'` in `ios/Podfile` and every
   `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj`.
2. **Cleartext + local network** in `ios/Runner/Info.plist` (the emulator is
   plain HTTP on the LAN):
   - `NSAppTransportSecurity` → `NSAllowsLocalNetworking` = `true`
   - `NSLocalNetworkUsageDescription` = a short reason string
3. **Signing** — `flutter create` usually picks up your Xcode team
   automatically; otherwise set a team on the Runner target in Xcode
   (Signing & Capabilities → automatic). A free/personal team is fine.

## On the device (first launch)

- **Trust the developer profile**: Settings → General → VPN & Device
  Management → your "Apple Development: …" profile → **Trust**. Until you do,
  the app installs but iOS blocks launch and `flutter run` hangs at
  "Installing and launching…".
- **Allow local network**: tap **Allow** on the "find devices on your local
  network" prompt, or Firebase can't reach the emulator.

## Gotchas

- The Mac and the device must be on the **same Wi-Fi / LAN**.
- If macOS pops a **firewall** prompt for Java (Firestore) or Node (Firebase
  CLI), allow incoming connections.
- The **LAN IP changes** when you switch networks — `dev_device.sh` re-detects
  it each run, so just re-run after moving networks.
- First device build compiles Firestore's C++ deps (BoringSSL, gRPC, leveldb,
  abseil) and can take **8–15 min**; subsequent runs are cached and fast.
