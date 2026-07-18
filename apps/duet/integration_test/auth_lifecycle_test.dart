// Drives the whole identity lifecycle — sign-up, directory publication,
// display-name edit, discoverable toggle, password reset, email
// verification, re-auth, and account deletion — against the REAL Firebase
// Auth + Firestore + Functions emulators (see `lib/main_emulator.dart`).
// This is the M1 exit criterion: the headless gate only ever exercises the
// in-memory fakes (`test/injection_test.dart`, `test/duet_flow_test.dart`),
// never this real backend, and the M1.8 functions tests prove the purge
// server-side in isolation — this proves the client stack drives it end to
// end.
//
// Like `collaborator_flow_test.dart`, it needs the emulators already running;
// it's opt-in via `melos run e2e-emulator` (excluded from the standard
// headless gate). It additionally needs the **Functions** emulator up (the
// deletion callable, M1.8) — start the backend with
// `apps/duet/dev.sh --emulators-only`, which boots Functions too.
//
// This suite is `dart:io`-free (M4.5): the emulator's REST surfaces are hit
// via `package:http` (which has a browser client on web), so it runs
// headlessly on the web engine (CI drives it with `flutter drive -d
// web-server` + chromedriver; `flutter test` refuses web devices for
// integration tests) as well as on a device/desktop.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/app.dart';
import 'package:duet/data/account_purge.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/directory_publisher.dart';
import 'package:duet/injection.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:user_directory/user_directory.dart';

const _authHost = '127.0.0.1:9099';
const _firestoreHost = '127.0.0.1:8080';
const _project = 'demo-duet';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = 'lifecycle.sam@duet.dev';
  const strangerEmail = 'lifecycle.mallory@duet.dev';
  const password = 'correct horse battery staple';

  testWidgets(
    'sign-up → directory → rename → hide → reset → verify → reauth → '
    'delete, all against the live emulator (M1 exit criterion)',
    (tester) async {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo',
          appId: '1:0:web:demo',
          messagingSenderId: '0',
          projectId: _project,
        ),
      );
      await firebase_auth.FirebaseAuth.instance.useAuthEmulator(
        '127.0.0.1',
        9099,
      );
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      await configureDependencies(useFirebase: true);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final auth = getIt<AuthRepository>();
      final directory = getIt<UserDirectory>();

      // 1. Sign up through the repository (not the raw SDK) — this is what
      // the app's own sign-up path calls, and it publishes the directory
      // entry via the eager `DirectoryPublisher` listening on the account
      // stream.
      expect(
        (await auth.signUp(
          email,
          password,
          displayName: 'Sam Lifecycle',
        )).isSuccess,
        isTrue,
      );
      await tester.pumpAndSettle();
      // `CurrentUser.call()` is non-nullable (empty string when signed out).
      final uid = getIt<CurrentUser>().call();
      expect(uid, isNotEmpty);

      // 2. The directory entry appears (published async off the account
      // stream), carrying the display name.
      final published = await _eventually(
        tester,
        () => directory.lookupByEmail(email),
        (r) => r.valueOrNull != null,
      );
      expect(published.valueOrNull?.displayName, 'Sam Lifecycle');

      // 3. Editing the display name re-publishes the entry.
      expect((await auth.updateDisplayName('Sam Renamed')).isSuccess, isTrue);
      await tester.pumpAndSettle();
      final renamed = await _eventually(
        tester,
        () => directory.lookupByEmail(email),
        (r) => r.valueOrNull?.displayName == 'Sam Renamed',
      );
      expect(renamed.valueOrNull?.displayName, 'Sam Renamed');

      // 4. Toggling discoverable off hides the entry from *other* accounts.
      // The owner can still resolve their own (rules allow self), so the
      // real test is a second account's lookup returning Success(null) — a
      // hidden entry must be indistinguishable from an absent one (this is
      // the path the M1.10 `lookupByEmail` fix covers: the rules DENY the
      // stranger's GET, which the directory maps to null rather than a
      // failure).
      final hidden = await getIt<DirectoryPublisher>().setDiscoverable(false);
      expect(hidden.isSuccess, isTrue);
      await tester.pumpAndSettle();

      await auth.logout();
      await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: strangerEmail,
        password: password,
      );
      await tester.pumpAndSettle();
      final strangerView = await directory.lookupByEmail(email);
      expect(strangerView, isA<Success<DirectoryUser?>>());
      expect(strangerView.valueOrNull, isNull);

      // Back to Sam for the rest of the lifecycle.
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await tester.pumpAndSettle();

      // 5. A password reset is really issued — assert the emulator minted an
      // oobCode for it (the only client-observable proof without an inbox).
      expect((await auth.sendPasswordReset(email)).isSuccess, isTrue);
      final resetCodes = await _oobCodes('PASSWORD_RESET', email);
      expect(resetCodes, isNotEmpty);

      // 6. Email verification is issued the same way.
      expect((await auth.sendEmailVerification()).isSuccess, isTrue);
      final verifyCodes = await _oobCodes('VERIFY_EMAIL', email);
      expect(verifyCodes, isNotEmpty);

      // 7. Re-authenticate (the deletion callable demands a fresh sign-in),
      // then delete the account through the same seam Settings uses.
      expect((await auth.reauthenticate(password: password)).isSuccess, isTrue);
      expect((await getIt<AccountPurge>().deleteAccount()).isSuccess, isTrue);
      await auth.logout();
      await tester.pumpAndSettle();

      // 8. The account is gone: sign-in now fails, and the purge removed the
      // directory entry, device tokens, and inbox (verified via the admin
      // REST surface, which bypasses rules).
      expect((await auth.login(email, password)).isSuccess, isFalse);
      expect(await _adminDirectoryCountForUid(uid), 0);
      expect(await _adminDocExists('deviceTokens/$uid'), isFalse);
      expect(await _adminCollectionCount('userInbox/$uid/messages'), 0);
    },
  );
}

/// Retries [probe] until [until] holds, pumping between attempts — the
/// directory publish is fire-and-forget off the account stream, so the
/// write lands a few frames after the triggering call.
Future<T> _eventually<T>(
  WidgetTester tester,
  Future<T> Function() probe,
  bool Function(T) until, {
  int tries = 50,
}) async {
  late T value;
  for (var i = 0; i < tries; i++) {
    value = await probe();
    if (until(value)) return value;
    await tester.pump(const Duration(milliseconds: 100));
  }
  return value;
}

/// The Auth emulator's out-of-band codes for [requestType]/[email] (the
/// `oobCodes` debug endpoint that stands in for an email inbox).
Future<List<dynamic>> _oobCodes(String requestType, String email) async {
  final body = await _getJson(
    Uri.parse('http://$_authHost/emulator/v1/projects/$_project/oobCodes'),
  );
  final codes = (body['oobCodes'] as List<dynamic>?) ?? const [];
  return codes
      .whereType<Map<String, dynamic>>()
      .where((c) => c['requestType'] == requestType && c['email'] == email)
      .toList();
}

String get _docsBase =>
    'http://$_firestoreHost/v1/projects/$_project/databases/(default)/documents';

/// How many `usersByEmail` docs carry [uid] (admin query, bypassing rules).
Future<int> _adminDirectoryCountForUid(String uid) async {
  final rows = await _postJsonList(
    Uri.parse('$_docsBase:runQuery'),
    <String, dynamic>{
      'structuredQuery': {
        'from': [
          {'collectionId': 'usersByEmail'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'uid'},
            'op': 'EQUAL',
            'value': {'stringValue': uid},
          },
        },
      },
    },
  );
  return rows.whereType<Map<String, dynamic>>().where((r) {
    return r.containsKey('document');
  }).length;
}

Future<bool> _adminDocExists(String path) async {
  final status = await _statusOf(Uri.parse('$_docsBase/$path'));
  return status == 200;
}

Future<int> _adminCollectionCount(String path) async {
  final body = await _getJson(Uri.parse('$_docsBase/$path'), admin: true);
  final docs = (body['documents'] as List<dynamic>?) ?? const [];
  return docs.length;
}

Future<Map<String, dynamic>> _getJson(Uri uri, {bool admin = false}) async {
  final response = await http.get(
    uri,
    headers: admin ? const {'Authorization': 'Bearer owner'} : null,
  );
  if (response.statusCode != 200) return <String, dynamic>{};
  if (response.body.isEmpty) return <String, dynamic>{};
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Future<int> _statusOf(Uri uri) async {
  final response = await http.get(
    uri,
    headers: const {'Authorization': 'Bearer owner'},
  );
  return response.statusCode;
}

Future<List<dynamic>> _postJsonList(Uri uri, Map<String, dynamic> body) async {
  final response = await http.post(
    uri,
    headers: const {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );
  if (response.statusCode != 200) return const [];
  return jsonDecode(response.body) as List<dynamic>;
}
