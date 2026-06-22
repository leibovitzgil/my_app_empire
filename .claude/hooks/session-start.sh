#!/bin/bash
set -euo pipefail

# SessionStart hook: prepare a Flutter/Melos workspace so the agent can run
# `melos run lint` / `melos run test` immediately. Runs only in Claude Code on
# the web; local developers manage their own SDK installation.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="${HOME}/flutter"
FLUTTER_CHANNEL="stable"

# 1. Install the Flutter SDK if it isn't already present. The container state is
#    cached after the hook completes, so this clone only happens once.
if ! command -v flutter >/dev/null 2>&1 && [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone --depth 1 --branch "${FLUTTER_CHANNEL}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

# 2. Put Flutter + pub-global binaries on PATH for this run and persist them for
#    the rest of the session.
export PATH="${FLUTTER_DIR}/bin:${HOME}/.pub-cache/bin:${PATH}"
echo "export PATH=\"${FLUTTER_DIR}/bin:\${HOME}/.pub-cache/bin:\${PATH}\"" >> "${CLAUDE_ENV_FILE}"

# 3. Warm the toolchain and install Melos.
flutter --version
dart pub global activate melos

# 4. Bootstrap the workspace so path-linked packages resolve.
cd "${CLAUDE_PROJECT_DIR}"
melos bootstrap
