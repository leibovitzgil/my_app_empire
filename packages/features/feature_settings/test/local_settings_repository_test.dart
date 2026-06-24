import 'package:core_utils/core_utils.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  group('LocalSettingsRepository', () {
    const key = 'settings_push_enabled';

    late LocalStorageService storage;
    late LocalSettingsRepository repository;

    setUp(() {
      storage = MockLocalStorageService();
      repository = LocalSettingsRepository(storage);
    });

    group('readPushEnabled', () {
      test('returns the persisted value when present', () async {
        when(() => storage.getBool(key)).thenReturn(true);

        final result = await repository.readPushEnabled();

        expect(result, isA<Success<bool>>());
        expect(result.valueOrNull, isTrue);
        verify(() => storage.getBool(key)).called(1);
      });

      // AC1: fresh install (no stored value) defaults to off.
      test('defaults to false when nothing is persisted', () async {
        when(() => storage.getBool(key)).thenReturn(null);

        final result = await repository.readPushEnabled();

        expect(result.valueOrNull, isFalse);
      });

      // Unhappy path: a throwing storage layer is folded into ResultFailure.
      test('storage throwing => ResultFailure (never throws)', () async {
        when(() => storage.getBool(key)).thenThrow(Exception('boom'));

        final result = await repository.readPushEnabled();

        expect(result, isA<ResultFailure<bool>>());
      });
    });

    group('writePushEnabled', () {
      // AC4: the chosen value is persisted under the stable key.
      test('persists true', () async {
        when(
          () => storage.setBool(key, true),
        ).thenAnswer((_) async => true);

        final result = await repository.writePushEnabled(true);

        expect(result, isA<Success<void>>());
        verify(() => storage.setBool(key, true)).called(1);
      });

      test('persists false', () async {
        when(
          () => storage.setBool(key, false),
        ).thenAnswer((_) async => true);

        final result = await repository.writePushEnabled(false);

        expect(result, isA<Success<void>>());
        verify(() => storage.setBool(key, false)).called(1);
      });

      // AC4 round-trip: a written value is read back unchanged.
      test('round-trips: write(true) then read => true', () async {
        var stored = false;
        when(() => storage.setBool(key, any<bool>())).thenAnswer((
          invocation,
        ) async {
          stored = invocation.positionalArguments[1] as bool;
          return true;
        });
        when(() => storage.getBool(key)).thenAnswer((_) => stored);

        await repository.writePushEnabled(true);
        final result = await repository.readPushEnabled();

        expect(result.valueOrNull, isTrue);
      });

      // Unhappy path: a throwing write is folded into ResultFailure.
      test('storage throwing => ResultFailure (never throws)', () async {
        when(
          () => storage.setBool(key, any<bool>()),
        ).thenThrow(Exception('boom'));

        final result = await repository.writePushEnabled(true);

        expect(result, isA<ResultFailure<void>>());
      });
    });
  });
}
