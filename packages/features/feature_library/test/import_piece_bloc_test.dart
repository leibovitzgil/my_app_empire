import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

class MockPdfRenderService extends Mock implements PdfRenderService {}

void main() {
  group('ImportPieceBloc', () {
    const sourcePath = '/tmp/source.pdf';
    final piece = Piece(
      id: 'p1',
      title: 'Nocturne',
      basePdfChecksum: 'checksum',
      basePdfPath: '/tmp/p1.pdf',
      ownerId: 'owner-1',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    late MockPieceRepository repository;
    late MockPdfRenderService renderService;

    setUp(() {
      repository = MockPieceRepository();
      renderService = MockPdfRenderService();
    });

    ImportPieceBloc buildBloc({required PdfFilePicker filePicker}) =>
        ImportPieceBloc(
          pieceRepository: repository,
          renderService: renderService,
          filePicker: filePicker,
        );

    test('initial state awaits a file pick', () {
      final bloc = buildBloc(filePicker: () async => null);
      addTearDown(bloc.close);
      expect(bloc.state.status, ImportStatus.awaitingPick);
    });

    blocTest<ImportPieceBloc, ImportPieceState>(
      'a cancelled pick stays at awaitingPick',
      build: () => buildBloc(filePicker: () async => null),
      act: (bloc) => bloc.add(const ImportPickRequested()),
      expect: () => <ImportPieceState>[],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'a valid PDF moves to naming with the suggested title',
      build: () {
        when(() => renderService.open(sourcePath)).thenAnswer(
          (_) async => const Success(3),
        );
        return buildBloc(
          filePicker: () async => const PickedPdfFile(
            path: sourcePath,
            suggestedTitle: 'Source',
          ),
        );
      },
      act: (bloc) => bloc.add(const ImportPickRequested()),
      expect: () => [
        isA<ImportPieceState>().having(
          (s) => s.status,
          'status',
          ImportStatus.validating,
        ),
        isA<ImportPieceState>()
            .having((s) => s.status, 'status', ImportStatus.naming)
            .having((s) => s.title, 'title', 'Source')
            .having((s) => s.sourcePath, 'sourcePath', sourcePath),
      ],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'an invalid/corrupt PDF moves to invalid with the failure detail',
      build: () {
        when(
          () => renderService.open(sourcePath),
        ).thenAnswer(
          (_) async => const ResultFailure(PdfRenderException('bad file')),
        );
        return buildBloc(
          filePicker: () async => const PickedPdfFile(
            path: sourcePath,
            suggestedTitle: 'Source',
          ),
        );
      },
      act: (bloc) => bloc.add(const ImportPickRequested()),
      skip: 1,
      expect: () => [
        isA<ImportPieceState>()
            .having((s) => s.status, 'status', ImportStatus.invalid)
            .having((s) => s.error, 'error', contains('bad file')),
      ],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'submitting a valid title creates the piece and moves to success',
      build: () {
        when(
          () => repository.importPiece(
            title: 'My title',
            sourcePath: sourcePath,
            ownerName: any(named: 'ownerName'),
          ),
        ).thenAnswer((_) async => Success(piece));
        return buildBloc(filePicker: () async => null);
      },
      seed: () => const ImportPieceState.naming(
        sourcePath: sourcePath,
        title: 'My title',
      ),
      act: (bloc) => bloc.add(const ImportSubmitted()),
      expect: () => [
        isA<ImportPieceState>().having(
          (s) => s.isSubmitting,
          'isSubmitting',
          true,
        ),
        isA<ImportPieceState>()
            .having((s) => s.status, 'status', ImportStatus.success)
            .having((s) => s.piece, 'piece', piece),
      ],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'a submit failure (e.g. permission-denied) keeps the naming form',
      build: () {
        when(
          () => repository.importPiece(
            title: 'My title',
            sourcePath: sourcePath,
            ownerName: any(named: 'ownerName'),
          ),
        ).thenAnswer(
          (_) async => ResultFailure(StateError('permission denied')),
        );
        return buildBloc(filePicker: () async => null);
      },
      seed: () => const ImportPieceState.naming(
        sourcePath: sourcePath,
        title: 'My title',
      ),
      act: (bloc) => bloc.add(const ImportSubmitted()),
      expect: () => [
        isA<ImportPieceState>().having(
          (s) => s.isSubmitting,
          'isSubmitting',
          true,
        ),
        isA<ImportPieceState>()
            .having((s) => s.status, 'status', ImportStatus.naming)
            .having((s) => s.isSubmitting, 'isSubmitting', false)
            .having(
              (s) => s.submitError,
              'submitError',
              contains('permission denied'),
            ),
      ],
    );
  });
}
