# crash_reporting

The factory's crash-reporting seam.

- **`CrashReporter`** — the contract apps and packages depend on:
  `recordError(error, stack, {fatal, context})`, `log(message)`,
  `setUserId(uid?)`. `setUserId` takes a **uid only — never an email** or
  any other PII.
- **`CrashlyticsCrashReporter`** — Firebase Crashlytics implementation.
  Construct it only after `Firebase.initializeApp()`, i.e. from a real
  Firebase entry point.
- **`NoopCrashReporter`** — for mock/emulator/headless compositions. The
  headless test gate must never construct a Firebase object, and the
  local emulator suite has no Crashlytics emulator anyway.
- **`installCrashHooks(reporter)`** — wires `FlutterError.onError`
  (chaining the previous handler, so the console dump survives) and
  `PlatformDispatcher.instance.onError` into the reporter. Call it from
  **real Firebase entry points only**, right after DI binds a
  `CrashlyticsCrashReporter`. Mock/emulator entry points bind the noop
  and never call it.

## Wiring in an app

```dart
// Real Firebase entry point (main_prod.dart / main_staging.dart):
await Firebase.initializeApp(...);
final reporter = CrashlyticsCrashReporter();
getIt.registerSingleton<CrashReporter>(reporter);
installCrashHooks(reporter);
```

Tie `setUserId` to the app's auth account stream (uid only), cleared on
sign-out — see `apps/duet/lib/data/crash_reporter_user_binder.dart` for
the reference glue.

## Native build wiring — [HUMAN], Track B (merge day)

Crashlytics needs native build integration that this package cannot
provide by itself; when the real Firebase project lands (M0.2):

1. Re-run `flutterfire configure` for the app so the Crashlytics Gradle
   plugin (`com.google.firebase.crashlytics`) and the Google Services
   plugin land in `android/settings.gradle` / `android/app/build.gradle`,
   and the iOS `firebase_app_id_file.json` / dSYM upload run-script phase
   is set up.
2. Verify with a forced test crash
   (`FirebaseCrashlytics.instance.crash()`) on a staging build and
   confirm it appears in the Crashlytics console dashboard (the M7.1 ▸B
   backlog item).
