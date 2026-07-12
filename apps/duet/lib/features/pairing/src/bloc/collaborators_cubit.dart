import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'collaborators_state.dart';

/// Drives the Collaborators screen for a single piece: the live roster (via
/// [PieceRepository.watchPieces]), an owner-only optimistic [remove], and
/// [leave] for a collaborator viewing their own row.
class CollaboratorsCubit extends Cubit<CollaboratorsState> {
  /// Creates a [CollaboratorsCubit] for [pieceId], viewed by
  /// [currentUserId].
  CollaboratorsCubit({
    required PieceRepository pieceRepository,
    required this.pieceId,
    required this.currentUserId,
  }) : _pieceRepository = pieceRepository,
       super(const CollaboratorsState.initial()) {
    _subscribe();
  }

  /// The piece whose collaborators this cubit manages.
  final String pieceId;

  /// The viewing device's current user id.
  final String currentUserId;

  final PieceRepository _pieceRepository;
  late StreamSubscription<List<Piece>> _subscription;

  void _subscribe() {
    _subscription = _pieceRepository.watchPieces().listen(
      _onPieces,
      onError: (Object error) => emit(
        state.copyWith(status: CollaboratorsStatus.failure, error: '$error'),
      ),
    );
  }

  /// Re-subscribes to the roster after a [CollaboratorsStatus.failure].
  Future<void> retry() async {
    await _subscription.cancel();
    emit(state.copyWith(status: CollaboratorsStatus.loading, clearError: true));
    _subscribe();
  }

  void _onPieces(List<Piece> pieces) {
    Piece? piece;
    for (final candidate in pieces) {
      if (candidate.id == pieceId) {
        piece = candidate;
        break;
      }
    }
    if (piece == null) {
      // No longer visible to this user (e.g. they just left, or were
      // removed) — an empty roster, not a failure.
      emit(
        state.copyWith(
          status: CollaboratorsStatus.empty,
          collaborators: const [],
          clearError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: piece.collaborators.isEmpty
            ? CollaboratorsStatus.empty
            : CollaboratorsStatus.success,
        ownerId: piece.ownerId,
        ownerName: piece.ownerName,
        collaborators: piece.collaborators,
        viewerIsOwner: piece.ownerId == currentUserId,
        clearError: true,
      ),
    );
  }

  /// Removes [uid] from the piece's collaborators. Owner-only (a no-op for
  /// any other viewer); updates the roster optimistically and reverts it if
  /// the repository call fails.
  Future<void> remove(String uid) async {
    if (!state.viewerIsOwner) return;
    final previous = state.collaborators;
    final optimistic = previous
        .where((collaborator) => collaborator.uid != uid)
        .toList();
    emit(
      state.copyWith(
        collaborators: optimistic,
        status: optimistic.isEmpty
            ? CollaboratorsStatus.empty
            : CollaboratorsStatus.success,
      ),
    );
    final result = await _pieceRepository.removeCollaborator(pieceId, uid);
    if (result case ResultFailure<void>(:final error)) {
      emit(
        state.copyWith(
          collaborators: previous,
          status: CollaboratorsStatus.success,
          error: '$error',
        ),
      );
    }
  }

  /// Removes the viewer's own collaborator entry from the piece.
  Future<Result<void>> leave() => _pieceRepository.leavePiece(pieceId);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
