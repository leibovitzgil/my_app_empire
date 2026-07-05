import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:user_roles/user_roles.dart';

part 'role_selection_state.dart';

/// Drives the one-time, post-signup Role Selection screen: a select-then-
/// confirm flow persisting the chosen [AppRole] via [UserRoleRepository].
class RoleSelectionCubit extends Cubit<RoleSelectionState> {
  /// Creates a [RoleSelectionCubit] persisting the choice for
  /// [currentUserId].
  RoleSelectionCubit({
    required UserRoleRepository userRoleRepository,
    required String Function() currentUserId,
  }) : _repository = userRoleRepository,
       _currentUserId = currentUserId,
       super(const RoleSelectionState());

  final UserRoleRepository _repository;
  final String Function() _currentUserId;

  /// Highlights [role] as the pending selection; does not persist it yet.
  void select(AppRole role) => emit(state.copyWith(selected: role));

  /// Persists the selected role. A no-op if nothing has been selected.
  Future<void> confirm() async {
    final role = state.selected;
    if (role == null) return;
    emit(
      state.copyWith(status: RoleSelectionStatus.saving, clearError: true),
    );
    final result = await _repository.assignRole(_currentUserId(), role);
    switch (result) {
      case Success<void>():
        emit(state.copyWith(status: RoleSelectionStatus.saved));
      case ResultFailure<void>(:final error):
        emit(
          state.copyWith(status: RoleSelectionStatus.error, error: '$error'),
        );
    }
  }
}
