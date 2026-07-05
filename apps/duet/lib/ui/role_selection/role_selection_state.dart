part of 'role_selection_cubit.dart';

/// The phase of [RoleSelectionCubit]'s save flow.
enum RoleSelectionStatus { idle, saving, saved, error }

/// Immutable state for [RoleSelectionCubit].
final class RoleSelectionState extends Equatable {
  /// Creates a [RoleSelectionState].
  const RoleSelectionState({
    this.status = RoleSelectionStatus.idle,
    this.selected,
    this.error,
  });

  /// The current phase.
  final RoleSelectionStatus status;

  /// The role highlighted (but not yet necessarily persisted) by the user.
  final AppRole? selected;

  /// A human-readable failure message, once [status] is
  /// [RoleSelectionStatus.error].
  final String? error;

  /// Returns a copy with the given fields replaced.
  RoleSelectionState copyWith({
    RoleSelectionStatus? status,
    AppRole? selected,
    String? error,
    bool clearError = false,
  }) {
    return RoleSelectionState(
      status: status ?? this.status,
      selected: selected ?? this.selected,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, selected, error];
}
