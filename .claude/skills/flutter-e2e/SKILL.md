---
name: flutter-e2e
description: Run or write end-to-end integration tests that drive the real app flow (onboarding, login, paywall). Use when asked to write an integration test, run E2E, drive the app through a flow, or verify the full app works end to end.
---

# End-to-end (integration_test)

E2E tests live in `apps/<app>/integration_test/` and drive the real widget tree
through a full flow. `apps/showcase/integration_test/app_flow_test.dart` walks
onboarding → login → home → paywall.

## Run it

- **Headless (no device):** `flutter test integration_test/` needs a device, so
  the same flow is mirrored as a widget test in `test/` and runs in the standard
  gate — that's the headless verification signal:
  ```bash
  melos run test            # includes the full-funnel widget test
  ```
- **On a device / simulator:**
  ```bash
  cd apps/showcase
  flutter test integration_test/app_flow_test.dart -d <device-id>
  ```
- **On web with screenshots (headless Chrome):** see the `run-app` skill / the
  web E2E script — drives the built web app via chromedriver and captures PNGs.

## Write one

Use `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, then `testWidgets`
with `tester.tap` / `tester.enterText` / `pumpAndSettle`, asserting on rendered
widgets at each step. Keep the headless `test/` mirror in sync so the flow stays
in the standard gate. Reset DI between tests (`tearDown(() => getIt.reset())`).
