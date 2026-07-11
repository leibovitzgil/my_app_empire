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

## PDFium native-asset download in sandboxed agent sessions

`pdfium_dart` (via `pdfrx` ← `pdf_rendering`) downloads `libpdfium.so` from
GitHub releases (`bblanchon/pdfium-binaries`) in a native-assets build hook
the first time `flutter test`/`flutter run` compiles a dependent package
(duet, pieces, feature_library, feature_pairing, feature_score,
pdf_rendering, review_sync). In Claude Code on the web sessions, outbound
GitHub fetches are scoped to the session's repositories, so that download is
denied (HTTP 403 "GitHub access to this repository is not enabled for this
session") and those packages' tests fail to *build*. CI and normal dev
machines are unaffected.

Workaround inside a sandboxed session — PyPI is reachable, and `pypdfium2`
wheels bundle a `libpdfium.so` built from the same `pdfium-binaries` project:

```bash
# 1. Download the latest pypdfium2 manylinux x86_64 wheel (see
#    https://pypi.org/pypi/pypdfium2/json) and unzip pypdfium2_raw/libpdfium.so.
# 2. Pre-seed it for each affected package (hook skips the download if present;
#    chromium_7811 matches the release pinned in pdfium_dart's hook/build.dart):
d=<package>/.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811/linux-x64
mkdir -p "$d" && cp libpdfium.so "$d/"
```

The bundled build number may trail/lead the pinned `chromium/7811` slightly;
pdfium's stable C API makes that fine for running tests.

When you hit something worth tracking, add it here with a short reproduction and
the package it affects.
