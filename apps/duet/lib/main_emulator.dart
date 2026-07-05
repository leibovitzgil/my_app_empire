import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duet/app.dart';
import 'package:duet/injection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Runs Duet against the local Firebase Emulator Suite (Auth + Firestore).
/// Run with `flutter run -t lib/main_emulator.dart` after starting
/// `firebase emulators:start` (config in `firebase.json`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo',
      appId: '1:0:web:demo',
      messagingSenderId: '0',
      projectId: 'demo-duet',
    ),
  );
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  await configureDependencies(useFirebase: true);
  runApp(const App());
}
