import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/src/data/pdf_file_picker.dart';
import 'package:equatable/equatable.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

part 'import_piece_event.dart';
part 'import_piece_state.dart';

/// Drives the Import PDF flow: pick a file, validate it opens as a real PDF
/// (via [PdfRenderService]), name it, create the piece
/// ([PieceRepository.importPiece]), then upload its base PDF with visible
/// progress ([PieceBinaryStore.uploadBasePdf]).
///
/// Validation failures (corrupt/unsupported PDF) are surfaced as a blocking
/// [ImportStatus.invalid] state — there's no useful form to show yet. Submit
/// failures (create *or* upload) keep the naming form intact and surface via
/// [ImportPieceState.submitError], a snackbar-level error, so the user doesn't
/// lose their edited title. The created piece is kept across an upload failure
/// (or a [ImportCancelled]) so a retry re-uploads rather than duplicating it.
class ImportPieceBloc extends Bloc<ImportPieceEvent, ImportPieceState> {
  /// Creates an [ImportPieceBloc]. [filePicker] defaults to
  /// [pickPdfFile]; inject a fake in tests to avoid the platform channel.
  ImportPieceBloc({
    required PieceRepository pieceRepository,
    required PdfRenderService renderService,
    required PieceBinaryStore binaryStore,
    PdfFilePicker? filePicker,
    this.ownerName,
  }) : _repository = pieceRepository,
       _renderService = renderService,
       _binaryStore = binaryStore,
       _filePicker = filePicker ?? pickPdfFile,
       super(const ImportPieceState.initial()) {
    on<ImportPickRequested>(_onPickRequested);
    on<ImportTitleChanged>(_onTitleChanged);
    on<ImportSubmitted>(_onSubmitted);
    on<ImportCancelled>(_onCancelled);
  }

  /// The importing user's display name, if known — sourced from auth
  /// identity by the caller and stored on the created [Piece].
  final String? ownerName;

  final PieceRepository _repository;
  final PdfRenderService _renderService;
  final PieceBinaryStore _binaryStore;
  final PdfFilePicker _filePicker;

  /// The in-flight upload subscription and the completer that keeps
  /// [_onSubmitted] alive until it finishes — held so [ImportCancelled] (which
  /// bloc processes concurrently) can abort the upload.
  StreamSubscription<UploadProgress>? _uploadSubscription;
  Completer<void>? _uploadCompleter;

  /// The piece created by a submit whose upload then failed or was cancelled —
  /// retained so a retry re-uploads it rather than importing a duplicate.
  /// Cleared once the upload succeeds.
  Piece? _createdPiece;

  Future<void> _onPickRequested(
    ImportPickRequested event,
    Emitter<ImportPieceState> emit,
  ) async {
    final picked = await _filePicker();
    if (picked == null) return; // Cancelled: stay put.
    emit(state.copyWith(status: ImportStatus.validating));
    final opened = await _renderService.open(picked.path);
    switch (opened) {
      case Success<int>():
        emit(
          ImportPieceState.naming(
            sourcePath: picked.path,
            title: picked.suggestedTitle,
          ),
        );
      case ResultFailure<int>(:final error):
        emit(ImportPieceState.invalid('$error'));
    }
  }

  void _onTitleChanged(
    ImportTitleChanged event,
    Emitter<ImportPieceState> emit,
  ) {
    if (state.status != ImportStatus.naming) return;
    emit(state.copyWith(title: event.title));
  }

  Future<void> _onSubmitted(
    ImportSubmitted event,
    Emitter<ImportPieceState> emit,
  ) async {
    final sourcePath = state.sourcePath;
    if (!state.canSubmit || sourcePath == null) return;
    emit(
      state.copyWith(isSubmitting: true, clearSubmitError: true, progress: 0),
    );

    // A retry after a failed/cancelled upload already has the piece — re-upload
    // only, rather than creating a duplicate.
    final Piece piece;
    final existing = _createdPiece;
    if (existing != null) {
      piece = existing;
    } else {
      final result = await _repository.importPiece(
        title: state.title.trim(),
        sourcePath: sourcePath,
        ownerName: ownerName,
      );
      switch (result) {
        case Success<Piece>(:final value):
          piece = value;
          _createdPiece = value;
        case ResultFailure<Piece>(:final error):
          emit(
            state.copyWith(
              isSubmitting: false,
              submitError: '$error',
              clearProgress: true,
            ),
          );
          return;
      }
    }
    if (emit.isDone) return; // Cancelled while importing.

    // Upload the base PDF, streaming progress. Driven via a managed
    // subscription (not `await for`) so ImportCancelled can abort it.
    final completer = Completer<void>();
    _uploadCompleter = completer;
    _uploadSubscription = _binaryStore
        .uploadBasePdf(
          pieceId: piece.id,
          localPath: piece.basePdfPath,
          checksum: piece.basePdfChecksum,
        )
        .listen(
          (progress) {
            if (!emit.isDone) {
              emit(state.copyWith(progress: progress.fraction));
            }
          },
          onError: (Object error) {
            // Keep [_createdPiece] so a retry re-uploads it.
            if (!emit.isDone) {
              emit(
                state.copyWith(
                  isSubmitting: false,
                  submitError: '$error',
                  clearProgress: true,
                ),
              );
            }
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            _createdPiece = null; // Import fully complete.
            if (!emit.isDone) {
              emit(
                state.copyWith(
                  status: ImportStatus.success,
                  piece: piece,
                  isSubmitting: false,
                ),
              );
            }
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
    await completer.future;
    _uploadSubscription = null;
    _uploadCompleter = null;
  }

  Future<void> _onCancelled(
    ImportCancelled event,
    Emitter<ImportPieceState> emit,
  ) async {
    final subscription = _uploadSubscription;
    if (subscription == null || !state.isSubmitting) return;
    await subscription.cancel();
    _uploadSubscription = null;
    // Back to the naming form; the created piece is kept for a retry.
    emit(state.copyWith(isSubmitting: false, clearProgress: true));
    _uploadCompleter?.complete();
    _uploadCompleter = null;
  }

  @override
  Future<void> close() async {
    await _uploadSubscription?.cancel();
    return super.close();
  }
}
