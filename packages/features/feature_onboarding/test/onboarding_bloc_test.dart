import 'package:bloc_test/bloc_test.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  group('OnboardingBloc', () {
    late LocalStorageService storage;

    setUp(() {
      storage = MockLocalStorageService();
      when(() => storage.setBool(any(), any())).thenAnswer((_) async => true);
    });

    OnboardingBloc build() => OnboardingBloc(storage: storage);

    test('initial state is page 0, not completed', () {
      final state = build().state;
      expect(state.page, 0);
      expect(state.completed, isFalse);
    });

    blocTest<OnboardingBloc, OnboardingState>(
      'advances to the next page when not on the last page',
      build: build,
      act: (bloc) => bloc.add(const OnboardingAdvanced()),
      expect: () => [
        isA<OnboardingState>().having((s) => s.page, 'page', 1),
      ],
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'completes and persists when advancing past the last page',
      build: build,
      seed: () => const OnboardingState(pageCount: 3, page: 2),
      act: (bloc) => bloc.add(const OnboardingAdvanced()),
      expect: () => [
        isA<OnboardingState>().having((s) => s.completed, 'completed', true),
      ],
      verify: (_) {
        verify(
          () => storage.setBool(OnboardingBloc.completedKey, true),
        ).called(1);
      },
    );
  });
}
