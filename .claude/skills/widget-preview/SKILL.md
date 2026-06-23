---
name: widget-preview
description: Add or browse Flutter widget previews (@Preview) to iterate on a widget in isolation with hot reload. Use when asked to preview a widget, build a design-system gallery, or develop UI without wiring a whole screen.
---

# Widget previews (`@Preview`)

Widget previews render a single widget hot-reloadably, without launching a full
app or wiring it into a screen — the fastest loop for developing a design-system
component in isolation. They complement goldens (which *diff* a rendered widget)
by giving an interactive, live view.

## Add a preview

Write a top-level (or static) function that returns a `Widget` and annotate it
with `@Preview`. Keep previews next to the widgets they showcase; in `core_ui`
they live in `lib/src/previews.dart` and are **not** exported from the barrel.

```dart
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

@Preview(name: 'PrimaryButton • enabled')
Widget primaryButtonEnabledPreview() {
  return PrimaryButton(label: 'Continue', onPressed: () {});
}

@Preview(name: 'PrimaryButton • loading')
Widget primaryButtonLoadingPreview() {
  return const PrimaryButton(
    label: 'Continue',
    onPressed: null,
    isLoading: true,
  );
}
```

Add one variant per meaningful state (enabled / loading / disabled, light /
dark, etc.) so the gallery documents the component's behaviour.

## Browse

```bash
cd apps/showcase            # any app that depends on the package
flutter widget-preview start
```

This opens a previewer that discovers every `@Preview` in the dependency graph
and hot-reloads as you edit.

## Notes

- Previews are **development-only** — the tooling excludes them from release
  builds, so they add no shipping weight.
- They render real widgets with real fonts (unlike headless goldens), but need a
  running previewer — in a headless container, reach for `golden` instead to
  capture a PNG.
- Keep previews lint-clean: they're compiled like any other source under the
  shared `very_good_analysis` rules.
