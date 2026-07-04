import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_pairing/src/domain/pairing_repository.dart';

part 'pairing_event.dart';
part 'pairing_state.dart';

class PairingBloc extends Bloc<PairingEvent, PairingState> {
  PairingBloc({required PairingRepository repository})
    : _repository = repository,
      super(const PairingState.initial()) {
    on<PairingRequested>(_onRequested);
  }

  final PairingRepository _repository;

  Future<void> _onRequested(
    PairingRequested event,
    Emitter<PairingState> emit,
  ) async {
    emit(const PairingState.loading());
    try {
      final value = await _repository.load();
      emit(PairingState.loaded(value));
    } on Exception catch (error) {
      emit(PairingState.failure(error.toString()));
    }
  }
}
