// Dev-only entry point: the emulator-wired app with the Flutter Driver
// extension enabled, so an agent (or `flutter drive`) can drive the real UI
// on a device/simulator against the local emulator suite.
//
//   flutter run -t lib/main_emulator_driver.dart -d <device>
//
// Never shipped: nothing imports this file; it exists solely as a `-t`
// target for interactive verification sessions. `flutter_driver` therefore
// deliberately stays a dev_dependency (release builds must not depend on
// the driver extension), which this dev-only entrypoint may reach into:
// ignore_for_file: depend_on_referenced_packages
import 'package:duet/main_emulator.dart' as emulator;
import 'package:flutter_driver/driver_extension.dart';

Future<void> main() async {
  enableFlutterDriverExtension();
  await emulator.main();
}
