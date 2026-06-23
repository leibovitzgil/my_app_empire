import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for `flutter drive` web/device E2E runs. Writes each screenshot taken
/// via `binding.takeScreenshot(name)` to `screenshots/<name>.png`.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('screenshots/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
