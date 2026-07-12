import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/src/bloc/collaborators_cubit.dart';
import 'package:duet/features/pairing/src/ui/invite_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Entry widget for the Collaborators screen: provides [CollaboratorsCubit]
/// for [pieceId] and renders [CollaboratorsScreen].
class CollaboratorsPage extends StatelessWidget {
  /// Creates a [CollaboratorsPage].
  const CollaboratorsPage({
    required this.pieceRepository,
    required this.pieceId,
    required this.currentUserId,
    this.onInvite,
    super.key,
  });

  /// Where the collaborator roster is loaded from and mutated.
  final PieceRepository pieceRepository;

  /// The piece whose collaborators this screen manages.
  final String pieceId;

  /// The viewing device's current user id.
  final String currentUserId;

  /// Called when the owner taps "Invite a friend", to open the invite sheet.
  /// A callback because the invite sheet's app-glue (services, owner name)
  /// lives at the app layer. `null` hides the invite action.
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollaboratorsCubit>(
      create: (_) => CollaboratorsCubit(
        pieceRepository: pieceRepository,
        pieceId: pieceId,
        currentUserId: currentUserId,
      ),
      child: CollaboratorsScreen(
        currentUserId: currentUserId,
        onInvite: onInvite,
      ),
    );
  }
}

/// The Collaborators body: an owner-first roster (owner, then every
/// collaborator), with an owner-only remove action on every collaborator row
/// but the viewer's own, and a "Leave" action on the viewer's own row.
/// Reads [CollaboratorsCubit] from context (provided by [CollaboratorsPage]).
class CollaboratorsScreen extends StatelessWidget {
  /// Creates a [CollaboratorsScreen].
  const CollaboratorsScreen({
    required this.currentUserId,
    this.onInvite,
    super.key,
  });

  /// The viewing device's current user id — used to render "You" and to
  /// decide which row (if any) gets the "Leave" affordance.
  final String currentUserId;

  /// See [CollaboratorsPage.onInvite].
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CollaboratorsCubit, CollaboratorsState>(
      listenWhen: (previous, current) =>
          current.error != null && current.error != previous.error,
      listener: (context, state) {
        if (state.error != null) AppSnackbar.error(context, state.error!);
      },
      builder: (context, state) {
        final canInvite = state.viewerIsOwner && onInvite != null;
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
            CollaboratorsStatus.empty => EmptyStateView(
              icon: Icons.group_outlined,
              title: 'No collaborators yet',
              message: 'Invite a friend to work on this sheet together.',
              action: canInvite
                  ? PrimaryButton(
                      label: 'Invite a friend',
                      onPressed: onInvite,
                    )
                  : null,
            ),
            CollaboratorsStatus.success => _CollaboratorsList(
              state: state,
              currentUserId: currentUserId,
              onInvite: canInvite ? onInvite : null,
            ),
          },
        );
      },
    );
  }
}

class _CollaboratorsList extends StatelessWidget {
  const _CollaboratorsList({
    required this.state,
    required this.currentUserId,
    this.onInvite,
  });

  final CollaboratorsState state;
  final String currentUserId;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
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
          ),
        ),
        if (onInvite != null)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SecondaryButton(
                label: 'Invite a friend',
                onPressed: onInvite,
              ),
            ),
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
        label: 'Leave this sheet',
        child: IconButton(
          tooltip: 'Leave this sheet',
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
      message: 'They will lose access to this sheet.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed) await cubit.remove(collaborator.uid);
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final cubit = context.read<CollaboratorsCubit>();
    final confirmed = await confirmDialog(
      context,
      title: 'Leave this sheet?',
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
