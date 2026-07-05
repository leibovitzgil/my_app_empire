import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result.guard', () {
    test('returns Success when the action completes', () async {
      final result = await Result.guard(() async => 42);
      expect(result, isA<Success<int>>());
      expect(result.valueOrNull, 42);
      expect(result.isSuccess, isTrue);
    });

    test('returns ResultFailure when the action throws', () async {
      final result = await Result.guard<int>(() async => throw Exception('x'));
      expect(result, isA<ResultFailure<int>>());
      expect(result.valueOrNull, isNull);
      expect(result.isSuccess, isFalse);
    });
  });

  test('fold maps both cases', () {
    const success = Success<int>(1);
    const failure = ResultFailure<int>('boom');
    expect(success.fold((v) => 'ok $v', (e) => 'err $e'), 'ok 1');
    expect(failure.fold((v) => 'ok $v', (e) => 'err $e'), 'err boom');
  });

  group('Result.orThrow', () {
    test('returns the value for a Success', () {
      const success = Success<int>(42);
      expect(success.orThrow(), 42);
    });

    test('rethrows an Exception error as-is', () {
      const failure = ResultFailure<int>(FormatException('bad'));
      expect(failure.orThrow, throwsFormatException);
    });

    test('rethrows an Error error as-is', () {
      final failure = ResultFailure<int>(StateError('bad state'));
      expect(failure.orThrow, throwsStateError);
    });

    test('wraps a non-Exception/Error failure in a StateError', () {
      const failure = ResultFailure<int>('boom');
      expect(() => failure.orThrow(), throwsStateError);
    });
  });
}
