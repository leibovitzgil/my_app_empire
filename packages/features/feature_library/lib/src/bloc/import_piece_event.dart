part of 'import_piece_bloc.dart';

sealed class ImportPieceEvent extends Equatable {
  const ImportPieceEvent();

  @override
  List<Object?> get props => [];
}

/// Opens the file picker. A no-op transition if the user cancels.
final class ImportPickRequested extends ImportPieceEvent {
  const ImportPickRequested();
}

/// The user edited the naming step's title field.
final class ImportTitleChanged extends ImportPieceEvent {
  const ImportTitleChanged(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

/// The user confirmed the naming step ("Create piece").
final class ImportSubmitted extends ImportPieceEvent {
  const ImportSubmitted();
}

/// The user cancelled an in-flight base-PDF upload, aborting it and returning
/// to the naming form (the created piece is kept for a later retry).
final class ImportCancelled extends ImportPieceEvent {
  const ImportCancelled();
}
