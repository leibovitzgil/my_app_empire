import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pieces/pieces.dart';

part 'library_event.dart';
part 'library_state.dart';

/// Drives the Home / Piece List screen: subscribes to
/// [PieceRepository.watchPieces] and exposes a role-aware view over the
/// result — grouped by student for a teacher, flat for a student — mirroring
/// how `ScoreBloc` resolves [PieceRole] from `currentUserId` rather than
/// depending on `user_roles` directly.
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  /// Creates a [LibraryBloc] for [currentUserId], already resolved to
  /// [currentRole] by the caller (the app-glue layer, typically from
  /// `user_roles`' `UserRoleRepository`).
  LibraryBloc({
    required PieceRepository pieceRepository,
    required String currentUserId,
    required PieceRole currentRole,
  }) : _repository = pieceRepository,
       super(
         LibraryState.initial(
           currentUserId: currentUserId,
           currentRole: currentRole,
         ),
       ) {
    on<LibraryStarted>(_onStarted);
    on<LibraryPiecesUpdated>(_onPiecesUpdated);
    on<LibraryFailed>(_onFailed);
    on<PieceViewed>(_onPieceViewed);
  }

  final PieceRepository _repository;
  StreamSubscription<List<Piece>>? _subscription;

  Future<void> _onStarted(
    LibraryStarted event,
    Emitter<LibraryState> emit,
  ) async {
    await _subscription?.cancel();
    emit(state.copyWith(status: LibraryStatus.loading, clearError: true));
    _subscription = _repository.watchPieces().listen(
      (pieces) => add(LibraryPiecesUpdated(pieces)),
      onError: (Object error) => add(LibraryFailed('$error')),
    );
  }

  void _onPiecesUpdated(
    LibraryPiecesUpdated event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(status: LibraryStatus.ready, pieces: event.pieces));
  }

  void _onFailed(LibraryFailed event, Emitter<LibraryState> emit) {
    emit(state.copyWith(status: LibraryStatus.failure, error: event.error));
  }

  void _onPieceViewed(PieceViewed event, Emitter<LibraryState> emit) {
    if (state.viewedPieceIds.contains(event.pieceId)) return;
    emit(
      state.copyWith(
        viewedPieceIds: {...state.viewedPieceIds, event.pieceId},
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
