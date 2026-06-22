# CLAUDE.md

Guidance for AI agents (and humans) working in this repository.

## What this is

`my_app_empire` is a **Flutter app factory**: a [Melos](https://melos.invertase.dev/)
monorepo of reusable packages plus app shells that compose them. New apps are
assembled from shared packages rather than built from scratch.

## Layout

```
apps/
  app_template/         # Composed reference app (auth + DI + go_router). Clone this.
  template_app/         # Minimal stub. See KNOWN_ISSUES.md.
packages/
  core/                 # Cross-cutting building blocks
    core_ui/ core_utils/ analytics_logger/ app_updater/
    legal_compliance/ local_storage/ monetization/ review_prompter/
  services/             # Integration wrappers (Firebase, network, etc.)
    analytics/ networking/ notifications/ remote_config/
  features/             # Vertical feature slices
    feature_auth/ feature_paywall/
```

- **`core/`** holds reusable building blocks. **`services/`** wraps external
  integrations. **`features/`** own a vertical slice (domain + data + bloc + ui)
  and may depend on `core/` and `services/`.
- **`apps/*`** wire packages together, supply concrete dependencies (real vs.
  mock repositories), and own routing.

## Commands

Run from the repo root. All use Melos.

| Task | Command |
| --- | --- |
| Install deps for all packages | `melos bootstrap` (alias `melos bs`) |
| Static analysis | `melos run lint` |
| Run tests | `melos run test` |
| Format | `melos run format` |
| Format check (CI) | `melos run format-check` |
| Scaffold a new app | `melos run create_app -- <name>` |
| Clean | `melos clean` |

**Always run `melos bootstrap` first** in a fresh checkout — packages link via
path dependencies and won't resolve otherwise.

## Linting

The root `analysis_options.yaml` uses [`very_good_analysis`](https://pub.dev/packages/very_good_analysis)
with `strict-casts`, `strict-inference`, and `strict-raw-types`. This is strict:
prefer single quotes, add type arguments to generic calls (e.g. `any<T>()`),
keep lines ≤ 80 chars, and avoid implicit `dynamic`. Run `melos run lint` before
committing.

> ⚠️ The workspace is **not currently fully green** — several pre-existing
> packages fail analysis. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md). When working in
> a package, get *that package* green; don't be misled by unrelated failures.

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
# or: melos run create_app -- my_new_app
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
