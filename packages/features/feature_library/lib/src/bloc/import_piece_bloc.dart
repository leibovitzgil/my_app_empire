import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_library/src/data/pdf_file_picker.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

part 'import_piece_event.dart';
part 'import_piece_state.dart';

/// Drives the Import PDF flow: pick a file, validate it opens as a real PDF
/// (via [PdfRenderService]), name it, then hand off to
/// [PieceRepository.importPiece].
///
/// Validation failures (corrupt/unsupported PDF) are surfaced as a blocking
/// [ImportStatus.invalid] state — there's no useful form to show yet. Submit
/// failures (e.g. permission-denied writing to disk) keep the naming form
/// intact and surface via [ImportPieceState.submitError], a snackbar-level
/// error, so the user doesn't lose their edited title.
class ImportPieceBloc extends Bloc<ImportPieceEvent, ImportPieceState> {
  /// Creates an [ImportPieceBloc]. [filePicker] defaults to
  /// [pickPdfFile]; inject a fake in tests to avoid the platform channel.
  ImportPieceBloc({
    required PieceRepository pieceRepository,
    required PdfRenderService renderService,
    PdfFilePicker? filePicker,
    this.ownerName,
  }) : _repository = pieceRepository,
       _renderService = renderService,
       _filePicker = filePicker ?? pickPdfFile,
       super(const ImportPieceState.initial()) {
    on<ImportPickRequested>(_onPickRequested);
    on<ImportTitleChanged>(_onTitleChanged);
    on<ImportSubmitted>(_onSubmitted);
  }

  /// The importing user's display name, if known — sourced from auth
  /// identity by the caller and stored on the created [Piece].
  final String? ownerName;

  final PieceRepository _repository;
  final PdfRenderService _renderService;
  final PdfFilePicker _filePicker;

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
    emit(state.copyWith(isSubmitting: true, clearSubmitError: true));
    final result = await _repository.importPiece(
      title: state.title.trim(),
      sourcePath: sourcePath,
      ownerName: ownerName,
    );
    switch (result) {
      case Success<Piece>(:final value):
        emit(
          state.copyWith(
            status: ImportStatus.success,
            piece: value,
            isSubmitting: false,
          ),
        );
      case ResultFailure<Piece>(:final error):
        emit(state.copyWith(isSubmitting: false, submitError: '$error'));
    }
  }
}
