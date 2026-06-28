import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:tandem/app.dart';
import 'package:tandem/injection.dart';

/// Runs Tandem against the local Firebase Emulator Suite (Firestore + Realtime
/// Database). Run with `flutter run -t lib/main_emulator.dart` after starting
/// `firebase emulators:start` (config in firebase.json).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo',
      appId: '1:0:web:demo',
      messagingSenderId: '0',
      projectId: 'demo-tandem',
      databaseURL: 'http://127.0.0.1:9000?ns=demo-tandem',
    ),
  );
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  FirebaseDatabase.instance.useDatabaseEmulator('127.0.0.1', 9000);
  await configureDependencies(useFirebase: true);
  runApp(const TandemApp());
}
