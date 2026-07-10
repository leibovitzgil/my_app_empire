import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:pieces/pieces.dart';

part 'piece_detail_state.dart';

/// Drives the Piece Detail screen: loads a single piece and mediates
/// rename/delete (owner) or leave (collaborator).
///
/// A [Cubit] rather than a [Bloc] — like `RecordAudioCubit`/
/// `AudioPlaybackCubit` in `feature_score` — since each action is a simple,
/// externally-triggered method rather than event-driven branching.
class PieceDetailCubit extends Cubit<PieceDetailState> {
  /// Creates a [PieceDetailCubit] for [currentUserId].
  PieceDetailCubit({
    required PieceRepository pieceRepository,
    required String currentUserId,
  }) : _repository = pieceRepository,
       _currentUserId = currentUserId,
       super(const PieceDetailState.initial());

  final PieceRepository _repository;
  final String _currentUserId;

  /// Loads [pieceId].
  Future<void> load(String pieceId) async {
    emit(
      state.copyWith(
        status: PieceDetailStatus.loading,
        pieceId: pieceId,
        clearError: true,
      ),
    );
    final result = await _repository.getPiece(pieceId);
    switch (result) {
      case Success<Piece>(:final value):
        emit(
          state.copyWith(
            status: PieceDetailStatus.ready,
            piece: value,
            currentRole: value.ownerId == _currentUserId
                ? PieceRole.owner
                : PieceRole.collaborator,
          ),
        );
      case ResultFailure<Piece>(:final error):
        emit(
          state.copyWith(status: PieceDetailStatus.failure, error: '$error'),
        );
    }
  }

  /// Renames the loaded piece. Owner only — the caller is expected to gate
  /// the affordance; the repository doesn't re-check ownership here.
  Future<void> rename(String title) async {
    final piece = state.piece;
    if (piece == null || title.trim().isEmpty) return;
    final trimmed = title.trim();
    final result = await _repository.renamePiece(piece.id, trimmed);
    switch (result) {
      case Success<void>():
        emit(state.copyWith(piece: piece.copyWith(title: trimmed)));
      case ResultFailure<void>(:final error):
        emit(state.copyWith(error: '$error'));
    }
  }

  /// Permanently deletes the loaded piece. Owner only.
  Future<void> delete() async {
    final piece = state.piece;
    if (piece == null) return;
    final result = await _repository.deletePiece(piece.id);
    switch (result) {
      case Success<void>():
        emit(state.copyWith(deleted: true));
      case ResultFailure<void>(:final error):
        emit(state.copyWith(error: '$error'));
    }
  }

  /// Leaves the loaded piece without deleting it. Collaborator only.
  Future<void> leave() async {
    final piece = state.piece;
    if (piece == null) return;
    final result = await _repository.leavePiece(piece.id);
    switch (result) {
      case Success<void>():
        emit(state.copyWith(left: true));
      case ResultFailure<void>(:final error):
        emit(state.copyWith(error: '$error'));
    }
  }
}
