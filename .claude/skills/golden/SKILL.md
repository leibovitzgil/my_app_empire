---
name: golden
description: Generate, view, and diff golden (screenshot) tests for visual UI verification. Use when asked to take a screenshot of a widget or screen, visually verify UI, check for visual regressions, or update goldens.
---

# Golden (screenshot) verification

Golden tests render a widget to a PNG and compare it on every run — the headless
way to "look at" UI without a device or browser. Use them to verify a UI change
or catch visual regressions.

## Write a golden test

Put it under `test/golden/`, tag it `golden`, and use a **network-free theme**
(`AppTheme` pulls `google_fonts`, which fetches at runtime and fails in tests):

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MyWidget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: MyWidget()),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MyWidget),
      matchesGoldenFile('goldens/my_widget.png'),
    );
  });
}
```

A package that has golden tests should also keep at least one regular test, so
the `test` gate (which runs `--exclude-tags golden`) isn't empty.

## Generate / view / diff

```bash
melos run update-goldens   # (re)generate PNGs under test/golden/goldens/
melos run golden           # compare against committed PNGs (the gate)
```

After generating, **read the PNG** to verify it looks right, and surface it to
the user. On a mismatch, `flutter test` writes
`test/golden/failures/*.png` (actual / diff) — read those to see what changed.

## Notes

- Text renders with a fallback font (real fonts aren't fetched headlessly), so
  goldens validate **layout/structure**, not typography.
- Goldens are environment-sensitive: generate and check them in the same
  environment (this container / the golden CI job), and commit the PNGs.
