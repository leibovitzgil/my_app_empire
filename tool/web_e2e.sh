#!/bin/bash
# Runs the showcase E2E flow in headless Chrome and writes screenshots to
# apps/showcase/screenshots/. Requires Chrome + chromedriver on PATH (the
# SessionStart hook provisions them on Claude Code on the web).
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/../apps/showcase" && pwd)"

if ! command -v chromedriver >/dev/null 2>&1; then
  echo "chromedriver not found on PATH. Install Chrome + chromedriver first" >&2
  echo "(the SessionStart hook does this on web sessions)." >&2
  exit 1
fi

cd "$APP_DIR"

chromedriver --port=4444 &
driver_pid=$!
trap 'kill "$driver_pid" 2>/dev/null || true' EXIT
sleep 2

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flow_test.dart \
  -d web-server \
  --browser-name=chrome \
  --headless

echo "Screenshots written to $APP_DIR/screenshots/"
