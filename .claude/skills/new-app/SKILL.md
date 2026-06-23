---
name: new-app
description: Scaffold a new Flutter app in apps/ from the canonical app_template (auth + DI + go_router). Use when the user wants to create a new app, add an app to the monorepo, or start a new product from the factory.
---

# Create a new app

Apps are minted from `app_template` (the single canonical template). Use the
generator rather than copying by hand.

## Steps

1. Pick a valid Dart package name in snake_case (e.g. `habit_tracker`).

2. Generate the app:

   ```bash
   dart run tool/create_app.dart <name> --description "<one-line description>"
   ```

   This clones `app_template` into `apps/<name>`, rewrites the package name, and
   skips generated artifacts.

3. Bootstrap, then regenerate dependency injection (the app uses `injectable`):

   ```bash
   melos bootstrap
   cd apps/<name> && dart run build_runner build --delete-conflicting-outputs
   ```

4. Add the `core_*`, `services/*`, and `feature_*` path dependencies the app
   needs, bind concrete repositories in `lib/data/` (annotate with
   `@LazySingleton(as: SomeRepository)`), and regenerate DI again.

5. Verify it's green:

   ```bash
   melos run lint && melos run test
   ```

See `CLAUDE.md` → "Adding a new app".
