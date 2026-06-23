import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:local_storage/local_storage.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

/// Tracks onboarding progress and persists completion so it is shown only once.
class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({required LocalStorageService storage, int pageCount = 3})
      : assert(pageCount > 0, 'pageCount must be positive'),
        _storage = storage,
        super(OnboardingState(pageCount: pageCount)) {
    on<OnboardingPageChanged>(
      (event, emit) => emit(state.copyWith(page: event.page)),
    );
    on<OnboardingAdvanced>(_onAdvanced);
  }

  final LocalStorageService _storage;

  /// Storage key recording that onboarding has been completed.
  static const completedKey = 'onboarding_completed';

  Future<void> _onAdvanced(
    OnboardingAdvanced event,
    Emitter<OnboardingState> emit,
  ) async {
    if (state.isLastPage) {
      await _storage.setBool(completedKey, true);
      emit(state.copyWith(completed: true));
    } else {
      emit(state.copyWith(page: state.page + 1));
    }
  }
}
