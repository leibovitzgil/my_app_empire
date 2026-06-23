---
name: run-app
description: Run or build a Flutter app from apps/ to verify a change works beyond analyze/test. Use when asked to run the app, build it, take a screenshot, or confirm a feature works end-to-end.
---

# Run / build an app for verification

`analyze` and `test` prove code is correct; running proves it composes. The
`showcase` app is the runnable reference (auth + onboarding + paywall, all on
mock/simulated backends — no Firebase/RevenueCat needed).

## Run

```bash
melos bootstrap
cd apps/showcase
flutter devices                 # pick a connected device / simulator
flutter run -d <device-id>
```

## Build (CI / artifact)

Generated apps don't include platform folders (`android/`, `ios/`, `web/`).
Materialize them once before building:

```bash
cd apps/<name>
flutter create .                # adds platform folders, keeps lib/
flutter build apk --debug       # or: flutter build web
```

## Headless verification

When no device is available, a widget test is the verification signal — pump the
app/screen and assert on what renders (see `apps/showcase/test/showcase_test.dart`).
Prefer adding/[running] a widget test over assuming a change works.
