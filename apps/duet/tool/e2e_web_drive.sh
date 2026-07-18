#!/usr/bin/env bash
# Runs Duet's `dart:io`-free emulator E2E suites (M4.5) headlessly in Chrome
# via `flutter drive -d web-server`.
#
# Why `flutter drive` and not `flutter test -d chrome`: `flutter test` refuses
# web devices for integration tests ("Web devices are not supported for
# integration tests yet"), so the only headless-web path is a `flutter drive`
# against a served app plus a WebDriver server (chromedriver). The two suites
# run here (`cloud_pieces_flow`, `auth_lifecycle`) were refactored off
# `dart:io` (HttpClient -> package:http, File uploads -> in-memory putData) so
# the web engine can compile and run them; `collaborator_flow` and
# `app_flow` still stage binaries via `dart:io` and stay on the device path
# (`melos run e2e`).
#
# Assumes the Firebase emulators are ALREADY running — the `melos run
# e2e-emulator` wrapper boots them with `firebase emulators:exec` and invokes
# this script inside that. Requires Chrome + a matching chromedriver on the
# runner (CI installs both via browser-actions/setup-chrome).
set -euo pipefail
cd "$(dirname "$0")/.."

driver_port=4444

# The web/ platform folder is git-ignored (generated), so create it on demand.
if [ ! -d web ]; then
  flutter create --platforms=web --project-name duet . >/dev/null
fi

# Start a WebDriver server (prefer one on PATH; fall back to npx download).
if command -v chromedriver >/dev/null 2>&1; then
  chromedriver --port="$driver_port" >/tmp/chromedriver.log 2>&1 &
else
  npx --yes chromedriver --port="$driver_port" >/tmp/chromedriver.log 2>&1 &
fi
driver_pid=$!
trap 'kill "$driver_pid" 2>/dev/null || true' EXIT

# Wait for chromedriver to accept sessions.
for _ in $(seq 1 30); do
  if curl -sf "http://localhost:$driver_port/status" >/dev/null; then break; fi
  sleep 1
done

for suite in cloud_pieces_flow_test auth_lifecycle_test; do
  echo "== flutter drive: $suite (headless web) =="
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="integration_test/${suite}.dart" \
    -d web-server --browser-name=chrome --headless \
    --driver-port="$driver_port"
done
