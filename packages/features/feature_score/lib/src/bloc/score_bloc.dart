import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_score/src/domain/score_repository.dart';

part 'score_event.dart';
part 'score_state.dart';

class ScoreBloc extends Bloc<ScoreEvent, ScoreState> {
  ScoreBloc({required ScoreRepository repository})
    : _repository = repository,
      super(const ScoreState.initial()) {
    on<ScoreRequested>(_onRequested);
  }

  final ScoreRepository _repository;

  Future<void> _onRequested(
    ScoreRequested event,
    Emitter<ScoreState> emit,
  ) async {
    emit(const ScoreState.loading());
    try {
      final value = await _repository.load();
      emit(ScoreState.loaded(value));
    } on Exception catch (error) {
      emit(ScoreState.failure(error.toString()));
    }
  }
}
