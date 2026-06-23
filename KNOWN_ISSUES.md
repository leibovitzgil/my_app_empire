# Known Issues

The workspace is fully green:
`melos bootstrap && melos run lint && melos run test && melos run format-check`
all pass across every package, under uniform strict `very_good_analysis`.

Historical items (duplicate packages, broken bootstrap, compile/lint failures,
two template apps, inconsistent lint baselines) have all been resolved — see the
git history for details.

## Web E2E prerequisite (not blocking the standard gate)

The headless web E2E engine (`tool/web_e2e.sh`) is wired and `flutter build web`
now succeeds for the showcase app (the old `firebase_auth_web` `handleThenable`
blocker was fixed by the upgrade to `firebase_core 4` / `firebase_auth 6`). One
environment prerequisite remains for a live run:

- **Chrome and chromedriver must share a major version.** The web driver fails if
  they drift (e.g. Chrome 141 with chromedriver 147). The SessionStart hook
  installs a matched pair on web sessions.

Golden tests (`melos run golden`) and the headless full-funnel widget test
(in `melos run test`) are the runtime-verification paths that run everywhere.

When you hit something worth tracking, add it here with a short reproduction and
the package it affects.
