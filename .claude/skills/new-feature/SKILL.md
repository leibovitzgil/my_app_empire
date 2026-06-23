---
name: new-feature
description: Scaffold a new feature_* package in this Flutter monorepo (domain/data/bloc/ui + bloc test) and wire it into an app. Use when the user wants to add a feature, a vertical slice, a screen with a bloc, or a new feature package.
---

# Create a new feature

This monorepo scaffolds features deterministically. Do **not** hand-create the
files — use the generator.

## Steps

1. Pick a snake_case feature name without the `feature_` prefix (e.g. `profile`,
   `user_settings`). Confirm with the user if ambiguous.

2. Generate the package:

   ```bash
   dart run tool/create_feature.dart <name> --description "<one-line description>"
   ```

   This creates `packages/features/feature_<name>/` with the `feature_auth`
   structure: `domain/` (repository contract), `data/` (in-memory impl),
   `bloc/` (bloc + event + state), `ui/` (screen), a barrel file, and a
   `bloc_test`.

3. Bootstrap and verify the new package is green:

   ```bash
   melos bootstrap
   melos run lint && melos run test
   ```

4. Implement the real behavior: flesh out the `*Repository` contract in
   `domain/`, add a concrete implementation in `data/`, and extend the bloc's
   events/states. Keep the repository as the testing/swapping seam.

5. To use it in an app, add the path dependency to the app's `pubspec.yaml`,
   bind a concrete repository in the app's DI layer, and regenerate DI if the
   app uses `injectable` (`dart run build_runner build`).

See `CLAUDE.md` → "Feature package anatomy" for the conventions to follow.
