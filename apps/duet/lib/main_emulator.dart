import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:duet/app.dart';
import 'package:duet/data/callable_account_purge.dart';
import 'package:duet/injection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:review_prompter/review_prompter.dart';

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

/// Runs Duet against the local Firebase Emulator Suite (Auth + Firestore +
/// Functions + Storage). Run with `flutter run -t lib/main_emulator.dart`
/// after starting `firebase emulators:start` (config in `firebase.json`).
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
      // Without a bucket the native SDK throws `no-bucket` from
      // `useStorageEmulator` before `runApp` — a blank screen. The name is
      // never resolved: the Storage emulator serves whatever it's given.
      storageBucket: 'demo-duet.appspot.com',
    ),
  );
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  // The same region-pinned instance `injection.dart` resolves for the
  // account-deletion callable (`instanceFor` caches per app+region).
  FirebaseFunctions.instanceFor(
    region: duetFunctionsRegion,
  ).useFunctionsEmulator(_emulatorHost, 5001);
  // Storage backs base-PDF upload/download (M3.3/M3.4) and audio notes (M3.5),
  // and the delete cascade (M3.8) sweeps its objects — point it at the local
  // Storage emulator (`firebase.json` :9199) too.
  await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, 9199);
  await configureDependencies(useFirebase: true);
  // Count this open toward the review-prompt threshold (M7.6) — same seam
  // as `main.dart`; fire-and-forget so it can never delay first frame.
  unawaited(
    getIt.getAsync<ReviewPrompter>().then(
      (prompter) => prompter.incrementAppOpenCount(),
    ),
  );
  runApp(const App());
}
