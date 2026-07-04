import 'package:bloc_test/bloc_test.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLibraryRepository extends Mock implements LibraryRepository {}

void main() {
  group('LibraryBloc', () {
    late LibraryRepository repository;

    setUp(() {
      repository = MockLibraryRepository();
    });

    test('initial state is initial', () {
      expect(
        LibraryBloc(repository: repository).state,
        const LibraryState.initial(),
      );
    });

    blocTest<LibraryBloc, LibraryState>(
      'emits [loading, loaded] when load succeeds',
      build: () {
        when(() => repository.load()).thenAnswer((_) async => 'value');
        return LibraryBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const LibraryRequested()),
      expect: () => const [
        LibraryState.loading(),
        LibraryState.loaded('value'),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits [loading, failure] when load throws',
      build: () {
        when(() => repository.load()).thenThrow(Exception('boom'));
        return LibraryBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const LibraryRequested()),
      expect: () => [
        const LibraryState.loading(),
        isA<LibraryState>().having(
          (s) => s.status,
          'status',
          LibraryStatus.failure,
        ),
      ],
    );
  });
}
