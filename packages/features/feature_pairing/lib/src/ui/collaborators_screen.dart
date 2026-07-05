import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/src/bloc/collaborators_cubit.dart';
import 'package:feature_pairing/src/ui/invite_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pieces/pieces.dart';

/// Entry widget for the Collaborators screen: provides [CollaboratorsCubit]
/// for [pieceId] and renders [CollaboratorsScreen].
class CollaboratorsPage extends StatelessWidget {
  /// Creates a [CollaboratorsPage].
  const CollaboratorsPage({
    required this.pieceRepository,
    required this.pieceId,
    required this.currentUserId,
    super.key,
  });

  /// Where the collaborator roster is loaded from and mutated.
  final PieceRepository pieceRepository;

  /// The piece whose collaborators this screen manages.
  final String pieceId;

  /// The viewing device's current user id.
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollaboratorsCubit>(
      create: (_) => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: pieceId,
        currentUserId: currentUserId,
      ),
      child: CollaboratorsScreen(currentUserId: currentUserId),
    );
  }
}

/// The Collaborators body: an owner-first roster (owner, then every
/// collaborator), with an owner-only remove action on every collaborator row
/// but the viewer's own, and a "Leave" action on the viewer's own row.
/// Reads [CollaboratorsCubit] from context (provided by [CollaboratorsPage]).
class CollaboratorsScreen extends StatelessWidget {
  /// Creates a [CollaboratorsScreen].
  const CollaboratorsScreen({required this.currentUserId, super.key});

  /// The viewing device's current user id — used to render "You" and to
  /// decide which row (if any) gets the "Leave" affordance.
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CollaboratorsCubit, CollaboratorsState>(
      listenWhen: (previous, current) =>
          current.error != null && current.error != previous.error,
      listener: (context, state) {
        if (state.error != null) AppSnackbar.error(context, state.error!);
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Collaborators')),
          body: switch (state.status) {
            CollaboratorsStatus.loading => const LoadingView(),
            CollaboratorsStatus.failure => ErrorRetryView(
              title: "Couldn't load collaborators",
              message: state.error,
              onRetry: () => unawaited(
                context.read<CollaboratorsCubit>().retry(),
              ),
            ),
            CollaboratorsStatus.empty => const EmptyStateView(
              icon: Icons.group_outlined,
              title: 'No collaborators yet',
              message: 'Invite someone to collaborate on this piece.',
            ),
            CollaboratorsStatus.success => _CollaboratorsList(
              state: state,
              currentUserId: currentUserId,
            ),
          },
        );
      },
    );
  }
}

class _CollaboratorsList extends StatelessWidget {
  const _CollaboratorsList({required this.state, required this.currentUserId});

  final CollaboratorsState state;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PersonTile(
          initials: InviteFormat.initialsFor(state.ownerId),
          color: Color(InviteFormat.colorValueFor(state.ownerId)),
          name:
              state.ownerName ??
              'Owner ${InviteFormat.initialsFor(state.ownerId)}',
          subtitle: 'Owner',
        ),
        for (final collaborator in state.collaborators)
          _CollaboratorRow(
            collaborator: collaborator,
            isViewer: collaborator.uid == currentUserId,
            viewerIsOwner: state.viewerIsOwner,
          ),
      ],
    );
  }
}

class _CollaboratorRow extends StatelessWidget {
  const _CollaboratorRow({
    required this.collaborator,
    required this.isViewer,
    required this.viewerIsOwner,
  });

  final Collaborator collaborator;
  final bool isViewer;
  final bool viewerIsOwner;

  @override
  Widget build(BuildContext context) {
    return PersonTile(
      initials: InviteFormat.initialsFor(collaborator.uid),
      color: Color(InviteFormat.colorValueFor(collaborator.uid)),
      name: isViewer ? 'You' : name,
      subtitle: collaborator.email,
      trailing: _trailingFor(context),
    );
  }

  String get name =>
      collaborator.name ?? InviteFormat.initialsFor(collaborator.uid);

  Widget? _trailingFor(BuildContext context) {
    if (isViewer) {
      return Semantics(
        button: true,
        label: 'Leave this piece',
        child: IconButton(
          tooltip: 'Leave this piece',
          icon: const Icon(Icons.logout),
          onPressed: () => _confirmLeave(context),
        ),
      );
    }
    if (viewerIsOwner) {
      return Semantics(
        button: true,
        label: 'Remove $name',
        child: IconButton(
          tooltip: 'Remove $name',
          icon: const Icon(Icons.person_remove_outlined),
          onPressed: () => _confirmRemove(context),
        ),
      );
    }
    // A collaborator viewing a peer's row (not their own, and not the
    // owner) sees no affordance at all — only the owner may remove others,
    // and only the viewer's own row offers "Leave".
    return null;
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final cubit = context.read<CollaboratorsCubit>();
    final confirmed = await confirmDialog(
      context,
      title: 'Remove $name?',
      message: 'They will lose access to this piece.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed) await cubit.remove(collaborator.uid);
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final cubit = context.read<CollaboratorsCubit>();
    final confirmed = await confirmDialog(
      context,
      title: 'Leave this piece?',
      message: "You'll lose access until invited again.",
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (!confirmed) return;
    final result = await cubit.leave();
    if (!context.mounted) return;
    if (result case ResultFailure<void>(:final error)) {
      AppSnackbar.error(context, '$error');
    } else {
      unawaited(Navigator.of(context).maybePop());
    }
  }
}
