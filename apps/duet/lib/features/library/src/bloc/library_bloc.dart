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
  /// Creates a [LibraryBloc] for [currentUserId]. [clock] stamps the
  /// optimistic "just opened" watermark on [PieceViewed]; defaults to
  /// [DateTime.now].
  LibraryBloc({
    required PieceRepository pieceRepository,
    required String currentUserId,
    DateTime Function()? clock,
  }) : _repository = pieceRepository,
       _now = clock ?? DateTime.now,
       super(LibraryState.initial(currentUserId: currentUserId)) {
    on<LibraryStarted>(_onStarted);
    on<LibraryPiecesUpdated>(_onPiecesUpdated);
    on<LibraryReadsUpdated>(_onReadsUpdated);
    on<LibraryFailed>(_onFailed);
    on<PieceViewed>(_onPieceViewed);
    on<LibraryFilterChanged>(_onFilterChanged);
    on<LibrarySearchChanged>(_onSearchChanged);
    on<LibrarySortChanged>(_onSortChanged);
  }

  final PieceRepository _repository;
  final DateTime Function() _now;
  StreamSubscription<List<Piece>>? _subscription;
  StreamSubscription<Map<String, DateTime>>? _readsSubscription;

  Future<void> _onStarted(
    LibraryStarted event,
    Emitter<LibraryState> emit,
  ) async {
    await _subscription?.cancel();
    await _readsSubscription?.cancel();
    emit(state.copyWith(status: LibraryStatus.loading, clearError: true));
    _subscription = _repository.watchPieces().listen(
      (pieces) => add(LibraryPiecesUpdated(pieces)),
      onError: (Object error) => add(LibraryFailed('$error')),
    );
    // The unread watermarks feed the dots only; a failure here shouldn't blank
    // the library (the piece stream owns the screen's status), so it has no
    // onError — the dots simply stop refreshing.
    _readsSubscription = _repository.watchReads().listen(
      (reads) => add(LibraryReadsUpdated(reads)),
    );
  }

  void _onPiecesUpdated(
    LibraryPiecesUpdated event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(status: LibraryStatus.ready, pieces: event.pieces));
  }

  void _onReadsUpdated(
    LibraryReadsUpdated event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(lastOpenedAt: event.reads));
  }

  void _onFailed(LibraryFailed event, Emitter<LibraryState> emit) {
    emit(state.copyWith(status: LibraryStatus.failure, error: event.error));
  }

  void _onPieceViewed(PieceViewed event, Emitter<LibraryState> emit) {
    // Optimistically clear the dot the instant the reader is opened from the
    // gallery — immediate feedback only, no persist. The reader itself is the
    // single writer of the watermark now (M4.3): it captures the pre-open
    // value, *then* calls `markOpened`, and the `watchReads` stream reconciles
    // this optimistic value once that write lands. Persisting here too would
    // bump the watermark before the reader captures it, defeating newness on
    // the gallery-open path.
    emit(
      state.copyWith(
        lastOpenedAt: {...state.lastOpenedAt, event.pieceId: _now()},
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
    await _readsSubscription?.cancel();
    return super.close();
  }
}
