import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

class MockPdfRenderService extends Mock implements PdfRenderService {}

/// A scriptable [PieceBinaryStore]: each call returns the stream produced by
/// [_onUpload], and records the piece id it was asked to upload (so a test can
/// assert an upload was — or wasn't — re-attempted).
class _FakeBinaryStore implements PieceBinaryStore {
  _FakeBinaryStore(this._onUpload);

  final Stream<UploadProgress> Function() _onUpload;
  final List<String> uploadedPieceIds = <String>[];

  @override
  Stream<UploadProgress> uploadBasePdf({
    required String pieceId,
    required String localPath,
    required String checksum,
  }) {
    uploadedPieceIds.add(pieceId);
    return _onUpload();
  }

  @override
  Future<Result<void>> downloadBasePdf({
    required String pieceId,
    required String destPath,
  }) => throw UnimplementedError();
}

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

    ImportPieceBloc buildBloc({
      required PdfFilePicker filePicker,
      PieceBinaryStore? binaryStore,
    }) => ImportPieceBloc(
      pieceRepository: repository,
      renderService: renderService,
      binaryStore: binaryStore ?? const NoopPieceBinaryStore(),
      filePicker: filePicker,
    );

    void whenImportSucceeds() => when(
      () => repository.importPiece(
        title: 'My title',
        sourcePath: sourcePath,
        ownerName: any(named: 'ownerName'),
      ),
    ).thenAnswer((_) async => Success(piece));

    const naming = ImportPieceState.naming(
      sourcePath: sourcePath,
      title: 'My title',
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
        when(
          () => renderService.open(sourcePath),
        ).thenAnswer((_) async => const Success(3));
        return buildBloc(
          filePicker: () async =>
              const PickedPdfFile(path: sourcePath, suggestedTitle: 'Source'),
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
          filePicker: () async =>
              const PickedPdfFile(path: sourcePath, suggestedTitle: 'Source'),
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
      'submitting creates the piece, uploads (no-op), and moves to success',
      build: () {
        whenImportSucceeds();
        return buildBloc(filePicker: () async => null);
      },
      seed: () => naming,
      act: (bloc) => bloc.add(const ImportSubmitted()),
      expect: () => [
        isA<ImportPieceState>()
            .having((s) => s.isSubmitting, 'isSubmitting', true)
            .having((s) => s.progress, 'progress', 0),
        // The no-op store reports an immediate skipped (fraction 1) upload.
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 1),
        isA<ImportPieceState>()
            .having((s) => s.status, 'status', ImportStatus.success)
            .having((s) => s.piece, 'piece', piece),
      ],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'reports upload progress from the store, then success',
      build: () {
        whenImportSucceeds();
        return buildBloc(
          filePicker: () async => null,
          binaryStore: _FakeBinaryStore(
            () => Stream.fromIterable(const [
              UploadProgress(bytesTransferred: 50, totalBytes: 100),
              UploadProgress(bytesTransferred: 100, totalBytes: 100),
            ]),
          ),
        );
      },
      seed: () => naming,
      act: (bloc) => bloc.add(const ImportSubmitted()),
      expect: () => [
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 0),
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 0.5),
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 1),
        isA<ImportPieceState>().having(
          (s) => s.status,
          'status',
          ImportStatus.success,
        ),
      ],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'an already-uploaded PDF (store reports skipped) still completes',
      build: () {
        whenImportSucceeds();
        return buildBloc(
          filePicker: () async => null,
          binaryStore: _FakeBinaryStore(
            () => Stream.value(const UploadProgress.skipped()),
          ),
        );
      },
      seed: () => naming,
      act: (bloc) => bloc.add(const ImportSubmitted()),
      expect: () => [
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 0),
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 1),
        isA<ImportPieceState>().having(
          (s) => s.status,
          'status',
          ImportStatus.success,
        ),
      ],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'a create failure keeps the naming form and never uploads',
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
        return buildBloc(
          filePicker: () async => null,
          binaryStore: _FakeBinaryStore(
            () => Stream.value(const UploadProgress.skipped()),
          ),
        );
      },
      seed: () => naming,
      act: (bloc) => bloc.add(const ImportSubmitted()),
      expect: () => [
        isA<ImportPieceState>().having(
          (s) => s.isSubmitting,
          'submitting',
          true,
        ),
        isA<ImportPieceState>()
            .having((s) => s.status, 'status', ImportStatus.naming)
            .having((s) => s.isSubmitting, 'isSubmitting', false)
            .having((s) => s.progress, 'progress', isNull)
            .having(
              (s) => s.submitError,
              'submitError',
              contains('permission'),
            ),
      ],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'an upload failure keeps the naming form (retry re-uploads)',
      build: () {
        whenImportSucceeds();
        return buildBloc(
          filePicker: () async => null,
          binaryStore: _FakeBinaryStore(
            () => Stream<UploadProgress>.error(StateError('storage down')),
          ),
        );
      },
      seed: () => naming,
      act: (bloc) => bloc.add(const ImportSubmitted()),
      expect: () => [
        isA<ImportPieceState>().having(
          (s) => s.isSubmitting,
          'submitting',
          true,
        ),
        isA<ImportPieceState>()
            .having((s) => s.status, 'status', ImportStatus.naming)
            .having((s) => s.isSubmitting, 'isSubmitting', false)
            .having((s) => s.progress, 'progress', isNull)
            .having((s) => s.submitError, 'submitError', contains('storage')),
      ],
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'retry after an upload failure re-uploads without re-creating the piece',
      build: () {
        whenImportSucceeds();
        var attempt = 0;
        return buildBloc(
          filePicker: () async => null,
          binaryStore: _FakeBinaryStore(() {
            attempt++;
            return attempt == 1
                ? Stream<UploadProgress>.error(StateError('storage down'))
                : Stream.value(const UploadProgress.skipped());
          }),
        );
      },
      seed: () => naming,
      act: (bloc) async {
        bloc.add(const ImportSubmitted());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const ImportSubmitted());
      },
      skip: 2, // first attempt: submitting, then upload-failure
      expect: () => [
        isA<ImportPieceState>().having((s) => s.isSubmitting, 'retry', true),
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 1),
        isA<ImportPieceState>().having(
          (s) => s.status,
          'status',
          ImportStatus.success,
        ),
      ],
      verify: (_) {
        // importPiece was called exactly once across both attempts.
        verify(
          () => repository.importPiece(
            title: 'My title',
            sourcePath: sourcePath,
            ownerName: any(named: 'ownerName'),
          ),
        ).called(1);
      },
    );

    blocTest<ImportPieceBloc, ImportPieceState>(
      'cancel aborts the in-flight upload and returns to the naming form',
      build: () {
        whenImportSucceeds();
        // An upload still in flight: one progress event, then the stream stays
        // open (never completes) until the subscription is cancelled — a
        // StreamController cancels promptly, like the real task stream.
        final upload = StreamController<UploadProgress>()
          ..add(const UploadProgress(bytesTransferred: 10, totalBytes: 100));
        addTearDown(upload.close);
        return buildBloc(
          filePicker: () async => null,
          binaryStore: _FakeBinaryStore(() => upload.stream),
        );
      },
      seed: () => naming,
      act: (bloc) async {
        bloc.add(const ImportSubmitted());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const ImportCancelled());
      },
      expect: () => [
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 0),
        isA<ImportPieceState>().having((s) => s.progress, 'progress', 0.1),
        isA<ImportPieceState>()
            .having((s) => s.status, 'status', ImportStatus.naming)
            .having((s) => s.isSubmitting, 'isSubmitting', false)
            .having((s) => s.progress, 'progress', isNull),
      ],
    );
  });
}
