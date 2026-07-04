import 'package:bloc_test/bloc_test.dart';
import 'package:feature_score/feature_score.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockScoreRepository extends Mock implements ScoreRepository {}

void main() {
  group('ScoreBloc', () {
    late ScoreRepository repository;

    setUp(() {
      repository = MockScoreRepository();
    });

    test('initial state is initial', () {
      expect(
        ScoreBloc(repository: repository).state,
        const ScoreState.initial(),
      );
    });

    blocTest<ScoreBloc, ScoreState>(
      'emits [loading, loaded] when load succeeds',
      build: () {
        when(() => repository.load()).thenAnswer((_) async => 'value');
        return ScoreBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const ScoreRequested()),
      expect: () => const [
        ScoreState.loading(),
        ScoreState.loaded('value'),
      ],
    );

    blocTest<ScoreBloc, ScoreState>(
      'emits [loading, failure] when load throws',
      build: () {
        when(() => repository.load()).thenThrow(Exception('boom'));
        return ScoreBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const ScoreRequested()),
      expect: () => [
        const ScoreState.loading(),
        isA<ScoreState>().having(
          (s) => s.status,
          'status',
          ScoreStatus.failure,
        ),
      ],
    );
  });
}
