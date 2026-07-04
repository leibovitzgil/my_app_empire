import 'package:bloc_test/bloc_test.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPairingRepository extends Mock implements PairingRepository {}

void main() {
  group('PairingBloc', () {
    late PairingRepository repository;

    setUp(() {
      repository = MockPairingRepository();
    });

    test('initial state is initial', () {
      expect(
        PairingBloc(repository: repository).state,
        const PairingState.initial(),
      );
    });

    blocTest<PairingBloc, PairingState>(
      'emits [loading, loaded] when load succeeds',
      build: () {
        when(() => repository.load()).thenAnswer((_) async => 'value');
        return PairingBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const PairingRequested()),
      expect: () => const [
        PairingState.loading(),
        PairingState.loaded('value'),
      ],
    );

    blocTest<PairingBloc, PairingState>(
      'emits [loading, failure] when load throws',
      build: () {
        when(() => repository.load()).thenThrow(Exception('boom'));
        return PairingBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const PairingRequested()),
      expect: () => [
        const PairingState.loading(),
        isA<PairingState>().having(
          (s) => s.status,
          'status',
          PairingStatus.failure,
        ),
      ],
    );
  });
}
