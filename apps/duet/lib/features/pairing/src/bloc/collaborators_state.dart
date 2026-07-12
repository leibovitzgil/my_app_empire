part of 'collaborators_cubit.dart';

/// The phase of [CollaboratorsCubit]'s Collaborators screen.
enum CollaboratorsStatus {
  /// Waiting on the first snapshot from [PieceRepository.watchPieces].
  loading,

  /// The piece has at least one collaborator.
  success,

  /// The piece currently has no collaborators.
  empty,

  /// The piece couldn't be found/loaded.
  failure,
}

/// Immutable state for [CollaboratorsCubit].
final class CollaboratorsState extends Equatable {
  const CollaboratorsState._({
    this.status = CollaboratorsStatus.loading,
    this.ownerId = '',
    this.ownerName,
    this.collaborators = const [],
    this.viewerIsOwner = false,
    this.error,
  });

  /// The initial state, before the first snapshot arrives.
  const CollaboratorsState.initial() : this._();

  /// The current phase.
  final CollaboratorsStatus status;

  /// The piece owner's id, so the screen can render an owner-first roster.
  final String ownerId;

  /// The piece owner's display name, if known.
  final String? ownerName;

  /// The piece's current collaborators, in insertion order.
  final List<Collaborator> collaborators;

  /// Whether the viewing device's current user is [ownerId] — gates the
  /// remove affordance on every row but the viewer's own.
  final bool viewerIsOwner;

  /// The most recent failure, if any — surfaced as a transient snackbar
  /// rather than replacing [status] (e.g. a failed optimistic removal
  /// reverts back to [CollaboratorsStatus.success] with this set).
  final String? error;

  /// Returns a copy with the given fields replaced.
  CollaboratorsState copyWith({
    CollaboratorsStatus? status,
    String? ownerId,
    String? ownerName,
    List<Collaborator>? collaborators,
    bool? viewerIsOwner,
    String? error,
    bool clearError = false,
  }) {
    return CollaboratorsState._(
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      collaborators: collaborators ?? this.collaborators,
      viewerIsOwner: viewerIsOwner ?? this.viewerIsOwner,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    ownerId,
    ownerName,
    collaborators,
    viewerIsOwner,
    error,
  ];
}
