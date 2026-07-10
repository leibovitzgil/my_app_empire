# CLAUDE.md

Guidance for AI agents (and humans) working in this repository.

## What this is

`my_app_empire` is a **Flutter app factory**: a [Melos](https://melos.invertase.dev/)
monorepo of reusable packages plus app shells that compose them. New apps are
assembled from shared packages rather than built from scratch.

## Layout

```
apps/
  app_template/         # Minimal app template (auth + DI + go_router). Clone for new apps.
  showcase/             # Reference app composing auth + onboarding + paywall via get_it.
packages/
  core/                 # Cross-cutting building blocks
    core_ui/ core_utils/ app_updater/ legal_compliance/
    local_storage/ monetization/ review_prompter/
  services/             # Integration wrappers (Firebase, network, etc.)
    analytics/ networking/ notifications/ remote_config/
  features/             # Vertical feature slices
    feature_auth/ feature_onboarding/ feature_paywall/
```

- **`core/`** holds reusable building blocks. `core_utils` includes a shared
  `Result<T>` type (`Success` / `ResultFailure`) for error handling without
  throwing across boundaries. **`services/`** wraps external integrations
  (`networking` returns `Result` and maps Dio errors to `NetworkException`).
  **`features/`** own a vertical slice (domain + data + bloc + ui).
- **`apps/*`** wire packages together via DI. See `apps/showcase/lib/injection.dart`
  for the canonical get_it wiring pattern (register a concrete implementation
  against the contract features depend on).

## Commands

Run from the repo root. All use Melos.

| Task | Command |
| --- | --- |
| Install deps for all packages | `melos bootstrap` (alias `melos bs`) |
| Static analysis | `melos run lint` |
| Run tests | `melos run test` |
| Format | `melos run format` |
| Format check (CI) | `melos run format-check` |
| Test with coverage | `melos run coverage` |
| Scaffold a new app | `dart run tool/create_app.dart <name>` |
| Scaffold a new feature | `dart run tool/create_feature.dart <name> [--wire <app>]` |
| Scaffold a core/service package | `dart run tool/create_package.dart <name> [--layer services] [--wire <app>]` |
| Install git hooks | `melos run install-hooks` |
| Clean | `melos clean` |

**Always run `melos bootstrap` first** in a fresh checkout — packages link via
path dependencies and won't resolve otherwise.

## Linting

Every package declares `very_good_analysis` and includes the root
`analysis_options.yaml`, so the **same strict rules apply uniformly** across the
whole workspace: `strict-casts`, `strict-inference`, `strict-raw-types`, single
quotes, explicit type arguments on generics (e.g. `any<T>()`), trailing commas,
and lines ≤ 80 chars. Generated files (`*.g.dart`, `*.config.dart`, `*.mocks.dart`,
`*.freezed.dart`) are excluded.

Two rules are intentionally disabled in the root config (with rationale):
`public_member_api_docs` (these are internal `publish_to: none` packages) and
`avoid_positional_boolean_parameters` (natural for setters). Run
`melos run lint` before committing; `dart fix --apply` resolves most findings
automatically. **The workspace is fully green — keep it that way.**

When adding a new package, give it a one-line `analysis_options.yaml`
(`include:` the root) and add `very_good_analysis` to its `dev_dependencies` so
the shared rules resolve.

## Code generation

Dependency injection in `app_template` uses
[`injectable`](https://pub.dev/packages/injectable), so
`apps/app_template/lib/injection.config.dart` is **generated, not hand-written**.
After adding or changing any `@injectable` / `@LazySingleton` annotation,
regenerate:

```bash
cd apps/app_template
dart run build_runner build --delete-conflicting-outputs
```

Do not edit `*.config.dart` by hand. Packages using `mockito` (e.g.
`services/notifications`) also need `build_runner` to generate `*.mocks.dart`.

## Feature package anatomy

Mirror `feature_auth` when creating a new feature:

```
feature_x/
  lib/
    feature_x.dart            # Barrel file: export the public API only
    src/
      domain/                 # Abstract contracts + entities (no I/O impl)
      data/                   # Concrete repository implementations
      bloc/                   # Bloc/event/state (state mgmt)
      ui/                     # Screens & widgets
  test/
```

Conventions, as exemplified by `feature_auth`:

- **State management:** `flutter_bloc`. Events/states are `sealed`/`final`
  classes extending an `Equatable` base; states are immutable with named
  constructors (`AuthState.authenticated(...)`).
- **Repositories:** define an abstract contract in `domain/`, implement it in
  `data/`. Apps choose the implementation at the DI layer (e.g.
  `MockAuthRepository` for `app_template`, `FirebaseAuthRepository` for prod).
  This is the primary testing/swapping seam — keep it clean.
- **Tests:** `bloc_test` with hand-written fakes or `mocktail`. Mock the
  repository, never the bloc.

## Adding a new app

Use the generator — it clones `app_template` and rewrites the package name:

```bash
dart run tool/create_app.dart my_new_app --description "My new app."
```

Then:

1. Add the package path dependencies you need to
   `apps/my_new_app/pubspec.yaml`.
2. Bind concrete implementations in `lib/data/` (annotate with
   `@LazySingleton(as: SomeRepository)`), then regenerate DI (see above).
3. `melos bootstrap && melos run lint && melos run test`.

The generator (`tool/create_app.dart`) is dependency-free (dart:io only) and
skips generated artifacts (`.dart_tool/`, `build/`, `pubspec.lock`, `*.iml`,
`pubspec_overrides.yaml`).

## Adding a new feature

Generate a feature package modelled on `feature_auth`:

```bash
dart run tool/create_feature.dart profile --description "User profile."
```

This creates `packages/features/feature_profile/` with the full vertical slice
(domain contract, in-memory data impl, bloc + event + state, screen, barrel) and
a passing bloc test. Then `melos bootstrap && melos run lint && melos run test`,
flesh out the repository/bloc, and wire it into an app (path dependency + DI).

## Agentic tooling

- **Generators** (`tool/create_app.dart`, `tool/create_feature.dart`,
  `tool/create_package.dart`): deterministic, dependency-free scaffolding.
  Prefer these over hand-creating packages so new code starts consistent and
  green. `create_feature`/`create_package` accept `--wire <app>` to also add the
  dependency and register the implementation in that app's get_it injection
  (at the `// generated:register` marker).
- **Subagents** (`.claude/agents/`): a feature-development pipeline of
  specialized agents — `product-manager` (spec + acceptance criteria) →
  `ux-designer` (flows + screen states on `core_ui`) → `architect` (package
  boundaries, contracts, bloc/DI plan) → `flutter-builder` (implements the
  slice) → `qa-engineer` (bloc/widget/golden/e2e tests + green gate) →
  `code-reviewer` (convention/correctness review). Delegate a feature through
  them in order for consistent, green results; for a small change invoke just
  the relevant one. Design/review agents are read-only; only the builder and QA
  write code.
- **Skills** (`.claude/skills/`): `new-app`, `new-feature`, `workspace-check`,
  `run-app`, `golden`, `flutter-e2e`, `widget-preview`, `screenshot`, and
  `duet-emulator` encode these workflows as slash-commands. `screenshot` builds
  an app for web and drives it with the pre-installed Playwright Chromium to
  capture real, readable screenshots of a live flow in this headless container —
  use it for visual feedback or to review your own UI work, versus `golden`'s
  exact but unreadable-text widget diffs. `duet-emulator` runs the Duet app
  against the local Firebase Emulator Suite (Auth + Firestore) with one command
  (`apps/duet/dev.sh`).
- **Reference app** (`apps/showcase`): a runnable composition (mock/simulated
  backends, no Firebase) — the golden example for wiring capabilities together.
- **Dart MCP server** (`.mcp.json`): wires the official `dart mcp-server` into
  agent sessions, exposing first-class tools for `analyze`, `dart fix`, running
  tests, and pub operations — plus runtime tools (hot reload, widget inspector,
  runtime errors) that light up when an app is actually running. Prefer these
  over shelling out to `dart`/`flutter` when available; they return structured
  results the agent can act on directly.
- **Widget previews** (`@Preview`): `core_ui` annotates design-system widgets
  (`lib/src/previews.dart`) with `@Preview` from
  `package:flutter/widget_previews.dart`. Browse them hot-reloadably with
  `flutter widget-preview start` (run from an app, e.g. `apps/showcase`) to
  iterate on a widget in isolation without wiring a whole screen. Previews are
  development-only and excluded from release builds. Skill: `widget-preview`.

### Runtime verification

Beyond `analyze`/`test`, the factory can verify the app actually runs and looks
right:

- **Golden tests** (`melos run golden`, `melos run update-goldens`): render
  widgets/screens to PNGs and diff them — headless screenshots, no device. Tag
  tests `golden`; the `test` gate excludes them (`--exclude-tags golden`). Skill:
  `golden`.
- **E2E** (`apps/showcase/integration_test/`): drives the full
  onboarding→login→home→paywall funnel. The same flow runs headless as a widget
  test in the standard gate; `melos run e2e` runs it on a device. Skill:
  `flutter-e2e`.
- **Web engine** (`tool/web_e2e.sh`): drives the built web app in headless
  Chrome with screenshots. Wired but has prerequisites — see
  [KNOWN_ISSUES.md](KNOWN_ISSUES.md).
- **Live screenshots** (skill: `screenshot`): builds any app for web and drives
  it with the pre-installed Playwright Chromium — a lower-prerequisite
  alternative to `tool/web_e2e.sh` for capturing real, human-readable
  screenshots of a live flow (not just widget-level golden diffs) for visual
  review by a human or the agent itself.
- **Pre-commit hook** (`.githooks/pre-commit`): runs format-check + lint. Enable
  with `melos run install-hooks`; bypass once with `git commit --no-verify`.
- **SessionStart hook** (`.claude/hooks/session-start.sh`): installs Flutter and
  bootstraps so Claude Code on the web sessions are build-ready.
