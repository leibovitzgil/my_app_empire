#!/usr/bin/env bash
#
# Duet — one command to run the app against local Firebase emulators.
#
#   ./dev.sh                    # emulators + app in Chrome (web)
#   ./dev.sh -d macos           # pick a device (chrome, macos, linux, ...)
#   ./dev.sh --no-seed          # don't create the demo accounts
#   ./dev.sh --emulators-only   # just the backend (Auth+Firestore+Functions+
#                               # Storage) — e.g. to run the integration_test/
#                               # e2e suites (collaborator_flow, auth_lifecycle)
#   ./dev.sh -- --profile       # everything after `--` is passed to flutter run
#
# Auth + Firestore + Functions + Storage run entirely on your machine in the
# "demo-duet" project: no real Firebase project, no login, nothing ever
# touches production. The emulators start empty each run; two demo accounts
# are seeded so you can sign in immediately (and invite each other by email):
#
#     you@duet.dev  /  password        friend@duet.dev  /  password
#
# Requirements: Flutter, Java (for the Firestore emulator), and Node/npm —
# npm builds the Cloud Functions in functions/, and the script falls back to
# `npx firebase-tools` when the Firebase CLI isn't on your PATH
# (`npm i -g firebase-tools` for the snappiest start).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---- config (override via flags / env) -------------------------------------
DEVICE="${DUET_DEVICE:-chrome}"
PROJECT="demo-duet"
ENTRYPOINT="lib/main_emulator.dart"
EMU_LOG="$SCRIPT_DIR/emulators-debug.log"
AUTH_HOST="127.0.0.1"; AUTH_PORT="9099"
FS_HOST="127.0.0.1";   FS_PORT="8080"
FN_HOST="127.0.0.1";   FN_PORT="5001"
ST_HOST="127.0.0.1";   ST_PORT="9199"
# Functions region — keep in sync with functions/src/region.ts (TODO(M0.H)).
REGION="europe-west1"
SEED=1
RUN_APP=1
FLUTTER_ARGS=()

say()  { printf '\033[1;36m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✖\033[0m %s\n' "$*" >&2; exit 1; }

# Print the leading comment block (line 2 up to the first non-`#` line),
# stripped of its `#` prefix.
usage() { awk 'NR==1{next} /^#/{sub(/^#+ ?/,"");print;next}{exit}' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--device)      DEVICE="${2:?-d needs a device}"; shift 2 ;;
    --no-seed)        SEED=0; shift ;;
    --emulators-only) RUN_APP=0; shift ;;
    --)               shift; while [ $# -gt 0 ]; do FLUTTER_ARGS+=("$1"); shift; done ;;
    -h|--help)        usage; exit 0 ;;
    *)                FLUTTER_ARGS+=("$1"); shift ;;
  esac
done

command -v flutter >/dev/null 2>&1 || die "Flutter is not on your PATH. See https://docs.flutter.dev/get-started"

# ---- resolve the Firebase CLI ----------------------------------------------
if command -v firebase >/dev/null 2>&1; then
  FIREBASE=(firebase)
elif command -v npx >/dev/null 2>&1; then
  say "Firebase CLI not found — using 'npx firebase-tools' (first run downloads it)."
  FIREBASE=(npx --yes firebase-tools)
else
  die "Need the Firebase CLI or Node/npx. Install with: npm i -g firebase-tools"
fi

# ---- ensure the target platform exists (apps here ship without it) ---------
# The monorepo's apps are composable packages with no committed platform
# scaffolding, so `flutter run` needs it generated once. Idempotent.
case "$DEVICE" in
  chrome|web-server|web) PLATFORM=web ;;
  macos)                 PLATFORM=macos ;;
  linux)                 PLATFORM=linux ;;
  windows)               PLATFORM=windows ;;
  *)                     PLATFORM="" ;;   # ios/android/device id — flutter handles
esac
if [ -n "$PLATFORM" ] && [ ! -d "$SCRIPT_DIR/$PLATFORM" ]; then
  say "Generating $PLATFORM platform scaffolding (first run only)…"
  flutter create --platforms="$PLATFORM" --project-name duet . >/dev/null
  # `flutter create` also drops a scaffold widget test that pumps a
  # non-existent `MyApp` — it would break `melos run test`, so drop it.
  rm -f "$SCRIPT_DIR/test/widget_test.dart"
fi

# ---- build the Cloud Functions (the emulator serves compiled lib/) ----------
# npm install + tsc, each skipped when its output is newer than its inputs so
# repeat runs stay fast.
FUNCTIONS_DIR="$SCRIPT_DIR/functions"
command -v npm >/dev/null 2>&1 || die "npm is required to build functions/. Install Node: https://nodejs.org"
if [ ! -d "$FUNCTIONS_DIR/node_modules" ] || \
   [ "$FUNCTIONS_DIR/package-lock.json" -nt "$FUNCTIONS_DIR/node_modules" ]; then
  say "Installing functions dependencies (first run / lockfile change)…"
  npm --prefix "$FUNCTIONS_DIR" ci --no-audit --no-fund >/dev/null
fi
if [ ! -d "$FUNCTIONS_DIR/lib" ] || \
   [ -n "$(find "$FUNCTIONS_DIR/src" "$FUNCTIONS_DIR/tsconfig.json" \
             "$FUNCTIONS_DIR/package.json" -newer "$FUNCTIONS_DIR/lib" \
             -print -quit)" ]; then
  say "Compiling functions…"
  npm --prefix "$FUNCTIONS_DIR" run build >/dev/null
  # Rewriting files inside lib/ doesn't bump the dir mtime — stamp it so the
  # freshness check above holds on the next run.
  touch "$FUNCTIONS_DIR/lib"
fi

# ---- teardown ---------------------------------------------------------------
EMU_PID=""
cleanup() {
  if [ -n "$EMU_PID" ] && kill -0 "$EMU_PID" 2>/dev/null; then
    printf '\n'; say "Stopping emulators…"
    kill "$EMU_PID" 2>/dev/null || true
    wait "$EMU_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# ---- start the emulators ----------------------------------------------------
say "Starting Firebase emulators (Auth + Firestore + Functions + Storage, project $PROJECT)…"
printf '  logs → %s\n' "$EMU_LOG"
"${FIREBASE[@]}" emulators:start --project "$PROJECT" \
  --only auth,firestore,functions,storage \
  >"$EMU_LOG" 2>&1 &
EMU_PID=$!

# ---- wait until healthy -----------------------------------------------------
# Pass -f where a 2xx is expected; the Storage emulator answers its root with
# a 501, so for it any HTTP response (vs. connection refused) means ready.
wait_for() { # url label [extra curl args...]
  local url="$1" label="$2" i; shift 2
  for i in $(seq 1 90); do
    if curl -s -o /dev/null --max-time 2 "$@" "$url"; then
      say "$label ready ($url)"; return 0
    fi
    kill -0 "$EMU_PID" 2>/dev/null || { tail -25 "$EMU_LOG" >&2; die "Emulators exited during startup."; }
    sleep 1
  done
  tail -25 "$EMU_LOG" >&2; die "Timed out waiting for $label ($url)."
}
wait_for "http://$AUTH_HOST:$AUTH_PORT/" "Auth emulator" -f
wait_for "http://$FS_HOST:$FS_PORT/"     "Firestore emulator" -f
wait_for "http://$ST_HOST:$ST_PORT/"     "Storage emulator"
# The callable answering proves the Functions emulator actually loaded the
# compiled functions, not just that its port is open.
wait_for "http://$FN_HOST:$FN_PORT/$PROJECT/$REGION/healthcheck" \
  "Functions emulator (healthcheck)" \
  -f -X POST -H 'Content-Type: application/json' -d '{"data":{}}'

# ---- seed demo accounts so you can sign in immediately ---------------------
# The app has no in-app sign-up (login is sign-in only), so a fresh emulator
# would have no accounts to log in with. Each account is created in the Auth
# emulator and published as a discoverable `usersByEmail` directory entry (the
# collaborator invite-by-email lookup target). Idempotent. The `Bearer owner`
# token is the emulator's admin credential — it bypasses firestore.rules,
# which is exactly what a seeding/import step should do.
seed_account() { # email password displayName
  local email="$1" pass="$2" name="$3" uid key
  local idt="http://$AUTH_HOST:$AUTH_PORT/identitytoolkit.googleapis.com/v1"
  local fs="http://$FS_HOST:$FS_PORT/v1/projects/$PROJECT/databases/(default)/documents"
  curl -fs -o /dev/null -X POST "$idt/accounts:signUp?key=demo" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$pass\",\"displayName\":\"$name\"}" 2>/dev/null || true
  uid=$(curl -fs -X POST "$idt/accounts:signInWithPassword?key=demo" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$pass\",\"returnSecureToken\":true}" 2>/dev/null \
    | grep -o '"localId":"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -n "$uid" ] || { warn "could not seed $email"; return 0; }
  key=$(printf '%s' "$email" | tr '[:upper:]' '[:lower:]')
  curl -fs -o /dev/null -X PATCH "$fs/usersByEmail/$key" \
    -H 'Authorization: Bearer owner' -H 'Content-Type: application/json' \
    -d "{\"fields\":{\"uid\":{\"stringValue\":\"$uid\"},\"email\":{\"stringValue\":\"$email\"},\"displayName\":{\"stringValue\":\"$name\"},\"discoverable\":{\"booleanValue\":true}}}" \
    2>/dev/null || true
}
if [ "$SEED" = 1 ]; then
  say "Seeding demo accounts (skip with --no-seed)…"
  seed_account "you@duet.dev"    "password" "You"
  seed_account "friend@duet.dev" "password" "Demo Friend"
  printf '\033[1;32m✔ Sign in with:\033[0m you@duet.dev / password   (invite: friend@duet.dev)\n'
fi

if [ "$RUN_APP" = 0 ]; then
  say "Emulators running (--emulators-only). Press Ctrl-C to stop."
  wait "$EMU_PID"
  exit 0
fi

# ---- run the app (foreground; owns the TTY for hot reload) ------------------
say "Launching Duet on '$DEVICE' → $ENTRYPOINT"
printf "  hot keys: r reload · R restart · q quit (quitting also stops the emulators)\n"
flutter run -t "$ENTRYPOINT" -d "$DEVICE" ${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"}
