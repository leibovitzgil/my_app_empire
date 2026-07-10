#!/usr/bin/env bash
#
# Duet — run the app on a physical iOS device against the local Firebase
# emulators. The companion to `dev.sh` (which targets web/desktop/simulator,
# all of which share the host's loopback).
#
#   ./dev_device.sh                 # first connected physical iOS device
#   ./dev_device.sh <device-id>     # a specific device (see `fvm flutter devices`)
#   EMU_HOST=192.168.1.20 ./dev_device.sh   # force the host IP the device dials
#
# A real device can't reach the emulators over 127.0.0.1 (that's the *device*),
# so this script:
#   1. finds your Mac's LAN IP,
#   2. starts the emulators bound to 0.0.0.0 (see firebase.json) + seeds them,
#      reusing `dev.sh --emulators-only`,
#   3. runs the app with --dart-define=EMU_HOST=<LAN IP> so Firebase Auth +
#      Firestore point at your Mac across the network,
#   4. uses `fvm flutter` when present, because the workspace pins the Flutter
#      SDK via FVM (a mismatched global `flutter` fails `pub get`).
#
# First run only, per machine, you must also (one-time, already done here):
#   - iOS deployment target >= 15.0 (cloud_firestore) in ios/Podfile +
#     ios/Runner.xcodeproj/project.pbxproj,
#   - NSAllowsLocalNetworking + NSLocalNetworkUsageDescription in
#     ios/Runner/Info.plist (the emulator is plain HTTP on the LAN),
#   - a signing team on the Runner target (Xcode > Signing & Capabilities).
# And on the device: trust the developer profile (Settings > General > VPN &
# Device Management) and allow the "find devices on your local network" prompt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

say()  { printf '\033[1;36m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✖\033[0m %s\n' "$*" >&2; exit 1; }

# ---- resolve Flutter (prefer FVM — the workspace pins the SDK there) --------
if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
elif command -v flutter >/dev/null 2>&1; then
  warn "fvm not found — using the global 'flutter' (may mismatch the pinned SDK)."
  FLUTTER=(flutter)
else
  die "Neither fvm nor flutter is on your PATH."
fi

# ---- your Mac's LAN IP (what the device dials) -----------------------------
lan_ip() {
  local ifc ip
  for ifc in en0 en1 en2; do
    ip="$(ipconfig getifaddr "$ifc" 2>/dev/null || true)"
    [ -n "$ip" ] && { printf '%s' "$ip"; return 0; }
  done
  return 1
}
HOST_IP="${EMU_HOST:-$(lan_ip || true)}"
[ -n "$HOST_IP" ] || die "Couldn't find your LAN IP. Set it: EMU_HOST=<ip> ./dev_device.sh"
say "Host (this Mac) LAN IP: $HOST_IP  — the device will reach the emulators here."

# ---- pick the target device -------------------------------------------------
DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  say "Looking for a connected physical iOS device…"
  DEVICE="$(
    "${FLUTTER[@]}" devices 2>/dev/null \
      | awk -F'•' 'tolower($0) ~ / ios / && tolower($0) !~ /simulator/ \
                   {gsub(/^ +| +$/,"",$2); print $2; exit}'
  )"
  [ -n "$DEVICE" ] || die "No physical iOS device found. Plug in + unlock it, then \`${FLUTTER[*]} devices\`, or pass an id."
fi
say "Target device: $DEVICE"

# ---- sanity-check the emulators are LAN-reachable ---------------------------
if ! grep -q '"host": "0.0.0.0"' firebase.json 2>/dev/null; then
  warn "firebase.json emulators aren't bound to 0.0.0.0 — the device may not reach them."
fi

# ---- start emulators + seed (reuse dev.sh; runs in the background) ----------
say "Starting emulators (Auth + Firestore, seeded) via dev.sh --emulators-only…"
./dev.sh --emulators-only -d "$DEVICE" &
EMU_WRAPPER_PID=$!
cleanup() {
  if kill -0 "$EMU_WRAPPER_PID" 2>/dev/null; then
    printf '\n'; say "Stopping emulators…"
    kill "$EMU_WRAPPER_PID" 2>/dev/null || true
    wait "$EMU_WRAPPER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# ---- wait until both emulators answer on the LAN IP -------------------------
wait_for() { # host port label
  local i
  for i in $(seq 1 90); do
    curl -fs -o /dev/null --max-time 2 "http://$1:$2/" && { say "$3 ready (http://$1:$2)"; return 0; }
    kill -0 "$EMU_WRAPPER_PID" 2>/dev/null || die "Emulators exited during startup (see emulators-debug.log)."
    curl -fs -o /dev/null --max-time 1 "http://127.0.0.1:$2/" 2>/dev/null || true
  done
  die "Timed out waiting for $3 at http://$1:$2 (firewall? both on the same Wi-Fi?)."
}
wait_for "$HOST_IP" 9099 "Auth emulator"
wait_for "$HOST_IP" 8080 "Firestore emulator"

# ---- run the app on the device ---------------------------------------------
say "Launching Duet on '$DEVICE' → lib/main_emulator.dart (EMU_HOST=$HOST_IP)"
printf "  first launch: trust the dev profile on the device + allow the local-network prompt.\n"
printf "  sign in: you@duet.dev / password   (invite: friend@duet.dev)\n"
"${FLUTTER[@]}" run -t lib/main_emulator.dart -d "$DEVICE" \
  --dart-define=EMU_HOST="$HOST_IP" "${@:2}"
