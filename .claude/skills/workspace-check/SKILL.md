---
name: workspace-check
description: Run the full quality gate for this Melos monorepo — bootstrap, format-check, lint, and test across every package. Use when the user wants to verify the workspace is green, run all checks, or confirm things pass before committing or opening a PR.
---

# Verify the workspace is green

Run the same checks CI runs, in order. Stop at the first failure and fix it
before continuing.

```bash
melos bootstrap          # link path packages (required after a fresh checkout)
melos run format-check   # dart format --set-exit-if-changed, all packages
melos run lint           # flutter analyze under very_good_analysis, all packages
melos run test           # flutter test for packages with a test/ dir
```

Notes:

- If `melos` or `flutter` aren't found, the Flutter SDK isn't on PATH. In a
  Claude Code on the web session the SessionStart hook installs it; otherwise
  ensure Flutter is installed.
- `dart fix --apply` (run per package or via `melos exec`) resolves most lint
  findings automatically; reformat afterward with `melos run format`.
- The workspace is expected to be fully green. A failure is a regression to fix,
  not an expected state.
