# Known Issues

The workspace is fully green:
`melos bootstrap && melos run lint && melos run test && melos run format-check`
all pass across every package, under uniform strict `very_good_analysis`.

Historical items (duplicate packages, broken bootstrap, compile/lint failures,
two template apps, inconsistent lint baselines) have all been resolved — see the
git history for details.

## Web E2E prerequisites (not blocking the standard gate)

The headless web E2E engine (`tool/web_e2e.sh`) is wired but has two environment
prerequisites:

- **`firebase_auth_web` doesn't compile for web** with the pinned
  `firebase_auth: ^4.10.0` (`handleThenable` / `MultiFactorResolver`). Apps that
  depend on `feature_auth` therefore can't `flutter build web` until the
  Firebase deps are bumped (a coordinated `firebase_core ^3` upgrade across the
  Firebase packages). Mobile/desktop builds are unaffected.
- **Chrome and chromedriver must share a major version.** The web driver fails if
  they drift (e.g. Chrome 141 with chromedriver 147). The SessionStart hook
  installs a matched pair on web sessions.

Until then, the working runtime-verification paths are **golden tests**
(`melos run golden`) and the **headless full-funnel widget test**
(in `melos run test`).

When you hit something worth tracking, add it here with a short reproduction and
the package it affects.
