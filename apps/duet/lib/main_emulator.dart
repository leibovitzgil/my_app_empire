import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duet/app.dart';
import 'package:duet/injection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Host the Firebase emulators are reachable at from *this* running app.
///
/// Defaults to `127.0.0.1`, which is correct for web / desktop / iOS
/// simulator (they share the host's loopback). A physical device can't reach
/// the host over loopback, so point it at the host's LAN IP:
///
///   flutter run -t lib/main_emulator.dart -d DEVICE
///     --dart-define=EMU_HOST=192.168.x.y
///
/// (and make sure the emulators bind to `0.0.0.0` — see `firebase.json`).
const String _emulatorHost = String.fromEnvironment(
  'EMU_HOST',
  defaultValue: '127.0.0.1',
);

/// A throwaway demo `GOOGLE_APP_ID` for the current platform.
///
/// The native Firebase SDKs (iOS/Android) validate `GOOGLE_APP_ID`: it must
/// carry the running platform token and a hex suffix, so a single `web` app id
/// crashes a real device with `'Configuration fails ... invalid
/// GOOGLE_APP_ID'`. (The web JS SDK never enforced this, which is why the same
/// id worked on web / desktop / the simulator.) The value is otherwise
/// meaningless — everything is redirected to the local emulators below.
String get _demoAppId {
  const hex = '0000000000000000';
  if (kIsWeb) return '1:0:web:demo';
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => '1:0:ios:$hex',
    TargetPlatform.android => '1:0:android:$hex',
    _ => '1:0:web:demo',
  };
}

/// Runs Duet against the local Firebase Emulator Suite (Auth + Firestore).
/// Run with `flutter run -t lib/main_emulator.dart` after starting
/// `firebase emulators:start` (config in `firebase.json`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      // The native iOS SDK (FirebaseInstallations) format-validates the API
      // key: 39 chars, leading `A`. It's a throwaway — every service is
      // redirected to the local emulators below — but must parse.
      apiKey: 'AIzaSyDEMOEMULATORKEYdemoemulatorkey012',
      appId: _demoAppId,
      messagingSenderId: '0',
      projectId: 'demo-duet',
    ),
  );
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  await configureDependencies(useFirebase: true);
  runApp(const App());
}
