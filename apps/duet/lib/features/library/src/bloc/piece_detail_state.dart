part of 'piece_detail_cubit.dart';

/// The phase of [PieceDetailCubit]'s loaded piece.
enum PieceDetailStatus { loading, ready, failure }

/// Immutable state for [PieceDetailCubit].
final class PieceDetailState extends Equatable {
  const PieceDetailState._({
    this.status = PieceDetailStatus.loading,
    this.pieceId,
    this.piece,
    this.currentRole = PieceRole.collaborator,
    this.error,
    this.deleted = false,
    this.left = false,
  });

  /// The initial state, before [PieceDetailCubit.load] resolves.
  const PieceDetailState.initial() : this._();

  /// The current phase.
  final PieceDetailStatus status;

  /// The id [PieceDetailCubit.load] was last called with, kept even on
  /// failure so the UI can retry.
  final String? pieceId;

  /// The loaded piece, once [status] is [PieceDetailStatus.ready].
  final Piece? piece;

  /// Whether the signed-in participant is [piece]'s owner or a collaborator.
  final PieceRole currentRole;

  /// The most recent failure (load or action), if any.
  final String? error;

  /// Whether [PieceDetailCubit.delete] succeeded — the screen should
  /// navigate back to the library.
  final bool deleted;

  /// Whether [PieceDetailCubit.leave] succeeded — the screen should navigate
  /// back to the library.
  final bool left;

  /// Returns a copy with the given fields replaced.
  PieceDetailState copyWith({
    PieceDetailStatus? status,
    String? pieceId,
    Piece? piece,
    PieceRole? currentRole,
    String? error,
    bool clearError = false,
    bool? deleted,
    bool? left,
  }) {
    return PieceDetailState._(
      status: status ?? this.status,
      pieceId: pieceId ?? this.pieceId,
      piece: piece ?? this.piece,
      currentRole: currentRole ?? this.currentRole,
      error: clearError ? null : (error ?? this.error),
      deleted: deleted ?? this.deleted,
      left: left ?? this.left,
    );
  }

  @override
  List<Object?> get props => [
    status,
    pieceId,
    piece,
    currentRole,
    error,
    deleted,
    left,
  ];
}
