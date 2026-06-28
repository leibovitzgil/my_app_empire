import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:tandem/app.dart';
import 'package:tandem/injection.dart';

/// Run on a real Firebase backend with
/// `flutter run --dart-define=USE_FIREBASE=true` after `flutterfire configure`
/// (and enabling Realtime Database). Defaults to the in-memory simulation so
/// the app runs out of the box.
const _useFirebase = bool.fromEnvironment('USE_FIREBASE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_useFirebase) {
    await Firebase.initializeApp();
  }
  // _useFirebase is false only without --dart-define=USE_FIREBASE=true.
  // ignore: avoid_redundant_argument_values
  await configureDependencies(useFirebase: _useFirebase);
  runApp(const TandemApp());
}
