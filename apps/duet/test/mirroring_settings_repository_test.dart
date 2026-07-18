import 'package:core_utils/core_utils.dart';
import 'package:duet/data/mirroring_settings_repository.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';

/// A [SettingsRepository] whose push write can be forced to fail, recording
/// what it was asked to persist.
class _FakeSettingsRepository implements SettingsRepository {
  bool stored = false;
  bool failWrite = false;
  final List<bool> writes = <bool>[];

  @override
  Future<Result<bool>> readPushEnabled() async => Success<bool>(stored);

  @override
  Future<Result<void>> writePushEnabled(bool enabled) async {
    if (failWrite) {
      return ResultFailure<void>(Exception('local write failed'));
    }
    writes.add(enabled);
    stored = enabled;
    return const Success<void>(null);
  }
}

void main() {
  group('MirroringSettingsRepository', () {
    late _FakeSettingsRepository delegate;
    late InMemoryUserMessaging registry;
    late String uid;
    late MirroringSettingsRepository repository;

    MirroringSettingsRepository build() => MirroringSettingsRepository(
      delegate: delegate,
      registry: registry,
      currentUserId: () => uid,
    );

    setUp(() {
      delegate = _FakeSettingsRepository();
      registry = InMemoryUserMessaging();
      uid = 'uid-1';
      repository = build();
    });

    test('writePushEnabled(true) persists locally and mirrors to the '
        'registry', () async {
      final result = await repository.writePushEnabled(true);

      expect(result, isA<Success<void>>());
      expect(delegate.writes, [true]);
      expect(registry.pushEnabledFor('uid-1'), isTrue);
    });

    test('writePushEnabled(false) mirrors the muted state', () async {
      await repository.writePushEnabled(true);

      await repository.writePushEnabled(false);

      expect(registry.pushEnabledFor('uid-1'), isFalse);
    });

    test('readPushEnabled delegates to the wrapped repository', () async {
      delegate.stored = true;

      final result = await repository.readPushEnabled();

      expect(result.valueOrNull, isTrue);
    });

    test('a failed local write fails the call and never mirrors', () async {
      delegate.failWrite = true;

      final result = await repository.writePushEnabled(true);

      expect(result, isA<ResultFailure<void>>());
      // The authoritative local write failed, so nothing was mirrored.
      expect(registry.pushEnabledFor('uid-1'), isNull);
    });

    test('a signed-out uid persists locally but skips the mirror', () async {
      uid = '';
      repository = build();

      final result = await repository.writePushEnabled(true);

      expect(result, isA<Success<void>>());
      expect(delegate.writes, [true]);
      // No `deviceTokens` doc exists for an empty uid to mirror onto.
      expect(registry.pushEnabledFor(''), isNull);
    });
  });
}
