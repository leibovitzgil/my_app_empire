part of 'import_piece_bloc.dart';

/// The phase of [ImportPieceBloc]'s import flow.
enum ImportStatus {
  /// No file picked yet; the screen shows a "choose a PDF" prompt.
  awaitingPick,

  /// [PdfRenderService.open] is validating the picked file.
  validating,

  /// The picked file failed to open as a PDF (corrupt/unsupported).
  invalid,

  /// A valid PDF was picked; the naming form is shown.
  naming,

  /// The piece was created.
  success,
}

/// Immutable state for [ImportPieceBloc].
final class ImportPieceState extends Equatable {
  const ImportPieceState._({
    this.status = ImportStatus.awaitingPick,
    this.sourcePath,
    this.title = '',
    this.isSubmitting = false,
    this.piece,
    this.error,
    this.submitError,
  });

  /// The initial state, before any file has been picked.
  const ImportPieceState.initial() : this._();

  /// The picked file failed [PdfRenderService.open].
  const ImportPieceState.invalid(String error)
    : this._(status: ImportStatus.invalid, error: error);

  /// A valid PDF was picked; ready to edit [title] and submit.
  const ImportPieceState.naming({required String sourcePath, String title = ''})
    : this._(
        status: ImportStatus.naming,
        sourcePath: sourcePath,
        title: title,
      );

  /// The current phase.
  final ImportStatus status;

  /// The on-device path of the picked (validated) PDF, once known.
  final String? sourcePath;

  /// The (editable) title shown in the naming step.
  final String title;

  /// Whether [PieceRepository.importPiece] is in flight.
  final bool isSubmitting;

  /// The created piece, once [status] is [ImportStatus.success].
  final Piece? piece;

  /// Why the picked file was rejected, once [status] is
  /// [ImportStatus.invalid].
  final String? error;

  /// A transient submit-time failure (e.g. permission-denied), surfaced as a
  /// snackbar rather than replacing the naming form.
  final String? submitError;

  /// Whether [ImportSubmitted] would currently do anything.
  bool get canSubmit =>
      status == ImportStatus.naming && !isSubmitting && title.trim().isNotEmpty;

  /// Returns a copy with the given fields replaced.
  ImportPieceState copyWith({
    ImportStatus? status,
    String? sourcePath,
    String? title,
    bool? isSubmitting,
    Piece? piece,
    String? error,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return ImportPieceState._(
      status: status ?? this.status,
      sourcePath: sourcePath ?? this.sourcePath,
      title: title ?? this.title,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      piece: piece ?? this.piece,
      error: error ?? this.error,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }

  @override
  List<Object?> get props => [
    status,
    sourcePath,
    title,
    isSubmitting,
    piece,
    error,
    submitError,
  ];
}
