// Pins `SignUpConsentBinder`'s core promise: a consent-checked sign-up records
// exactly one acceptance against the new account, and only then — a returning
// sign-in (no pending intent) records nothing.
import 'dart:async';

import 'package:duet/data/in_memory_consent_recorder.dart';
import 'package:duet/data/sign_up_consent_binder.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<AuthAccount?> accounts;
  late InMemoryConsentRecorder recorder;
  late SignUpConsentBinder binder;

  const account = AuthAccount(uid: 'user-1', email: 'jane@duet.dev');
  const version = '2026-07-17';

  setUp(() {
    accounts = StreamController<AuthAccount?>.broadcast();
    recorder = InMemoryConsentRecorder();
    binder = SignUpConsentBinder(accounts: accounts.stream, recorder: recorder);
  });

  tearDown(() async {
    await binder.dispose();
    await accounts.close();
  });

  Future<void> emit(AuthAccount? value) async {
    accounts.add(value);
    await Future<void>.delayed(Duration.zero);
  }

  test('records the acceptance against the account that signs up', () async {
    binder.markPending(version);
    await emit(account);

    expect(recorder.records, hasLength(1));
    expect(recorder.records.single.userId, 'user-1');
    expect(recorder.records.single.documentVersion, version);
  });

  test('records nothing when no sign-up consent is pending', () async {
    await emit(account);

    expect(recorder.records, isEmpty);
  });

  test(
    'ignores a null (signed-out) emission and waits for the account',
    () async {
      binder.markPending(version);
      await emit(null);
      expect(recorder.records, isEmpty);

      await emit(account);
      expect(recorder.records, hasLength(1));
    },
  );

  test(
    'consumes the pending intent — a later emission does not re-record',
    () async {
      binder.markPending(version);
      await emit(account);
      // A re-emission of the same account (e.g. a stream replay) must not
      // record a second acceptance.
      await emit(account);

      expect(recorder.records, hasLength(1));
    },
  );
}
