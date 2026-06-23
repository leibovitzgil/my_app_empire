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
}
