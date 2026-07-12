import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:duet/domain/domain.dart';
import 'package:equatable/equatable.dart';

part 'library_event.dart';
part 'library_state.dart';

/// Drives the Home / Sheet Library screen: subscribes to
/// [PieceRepository.watchPieces] and exposes the result partitioned into the
/// user's own sheets ([LibraryState.myPieces]) and sheets shared with them
/// ([LibraryState.sharedWithMe]).
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  /// Creates a [LibraryBloc] for [currentUserId].
  LibraryBloc({
    required PieceRepository pieceRepository,
    required String currentUserId,
  }) : _repository = pieceRepository,
       super(LibraryState.initial(currentUserId: currentUserId)) {
    on<LibraryStarted>(_onStarted);
    on<LibraryPiecesUpdated>(_onPiecesUpdated);
    on<LibraryFailed>(_onFailed);
    on<PieceViewed>(_onPieceViewed);
    on<LibraryFilterChanged>(_onFilterChanged);
    on<LibrarySearchChanged>(_onSearchChanged);
    on<LibrarySortChanged>(_onSortChanged);
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

  void _onFilterChanged(
    LibraryFilterChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  void _onSearchChanged(
    LibrarySearchChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(query: event.query));
  }

  void _onSortChanged(LibrarySortChanged event, Emitter<LibraryState> emit) {
    emit(state.copyWith(sort: event.sort));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
