// Dev-only entry point: the emulator-wired app with the Flutter Driver
// extension enabled, so an agent (or `flutter drive`) can drive the real UI
// on a device/simulator against the local emulator suite.
//
//   flutter run -t lib/main_emulator_driver.dart -d <device>
//
// Never shipped: nothing imports this file; it exists solely as a `-t`
// target for interactive verification sessions.
import 'package:flutter_driver/driver_extension.dart';

import 'main_emulator.dart' as emulator;

Future<void> main() async {
  enableFlutterDriverExtension();
  await emulator.main();
}
