import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_library/src/domain/library_repository.dart';

part 'library_event.dart';
part 'library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc({required LibraryRepository repository})
    : _repository = repository,
      super(const LibraryState.initial()) {
    on<LibraryRequested>(_onRequested);
  }

  final LibraryRepository _repository;

  Future<void> _onRequested(
    LibraryRequested event,
    Emitter<LibraryState> emit,
  ) async {
    emit(const LibraryState.loading());
    try {
      final value = await _repository.load();
      emit(LibraryState.loaded(value));
    } on Exception catch (error) {
      emit(LibraryState.failure(error.toString()));
    }
  }
}
