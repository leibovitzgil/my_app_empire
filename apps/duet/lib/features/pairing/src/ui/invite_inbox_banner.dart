import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:duet/features/pairing/src/bloc/invite_inbox_cubit.dart';
import 'package:duet/features/pairing/src/domain/collaborator_invite_service.dart';
import 'package:duet/features/pairing/src/ui/invite_format.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';

/// The pending-invites banner for the library surface (M5.6): one row per
/// invite addressed to [currentUserId] — "Maya invited you to collaborate on
/// a sheet — Accept / Dismiss" — fed live by
/// [CollaboratorInviteService.watchInvites]. Renders nothing while the inbox
/// has no pending invites.
///
/// Accept goes through [CollaboratorInviteService.acceptInvite] (the M2.4
/// callable path under Firebase); success fires [onAccepted] with the
/// now-joined piece's id so the app-glue layer can navigate to it (this
/// package never navigates), and the joined sheet appears in the gallery
/// below via `watchPieces`. An accept refused by the collaborator-cap
/// re-check defers to the same paywall-gate pattern as the invite sheet's
/// at-cap body: `feature_paywall`'s `PaywallScreen`, rendered in a bottom
/// sheet. Dismiss marks the message read — only that; the sender is
/// unaffected.
///
/// Wire it at the app layer above the library, like
/// `EmailVerificationBanner` — mirroring how `HomeScreen` composes the
/// library's banners (banners are transient UI, not route destinations).
class InviteInboxBanner extends StatelessWidget {
  /// Creates an [InviteInboxBanner].
  const InviteInboxBanner({
    required this.collaboratorInviteService,
    required this.messageGateway,
    required this.monetizationService,
    required this.currentUserId,
    required this.onAccepted,
    this.currentUserName,
    this.currentUserEmail,
    super.key,
  });

  /// Streams pending invites and accepts them.
  final CollaboratorInviteService collaboratorInviteService;

  /// Marks a dismissed invite's underlying inbox message read.
  final UserMessageGateway messageGateway;

  /// Backs the paywall gate shown when an accept is refused at-cap.
  final MonetizationService monetizationService;

  /// The signed-in user's id.
  final String currentUserId;

  /// The signed-in user's display name, if known — recorded on the piece's
  /// collaborator entry by the accept.
  final String? currentUserName;

  /// The signed-in user's email, if known — see [currentUserName] (AC-2).
  final String? currentUserEmail;

  /// Called once an invite is accepted, with the now-joined piece's id, so
  /// the app-glue layer can navigate into it.
  final void Function(String pieceId) onAccepted;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InviteInboxCubit>(
      create: (_) => InviteInboxCubit(
        collaboratorInviteService: collaboratorInviteService,
        messageGateway: messageGateway,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserEmail: currentUserEmail,
      ),
      child: _InviteInboxView(
        monetizationService: monetizationService,
        onAccepted: onAccepted,
      ),
    );
  }
}

class _InviteInboxView extends StatelessWidget {
  const _InviteInboxView({
    required this.monetizationService,
    required this.onAccepted,
  });

  final MonetizationService monetizationService;
  final void Function(String pieceId) onAccepted;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InviteInboxCubit, InviteInboxState>(
      // Each action resets status to `idle` before resolving, so two
      // same-outcome actions in a row still both notify here.
      listenWhen: (previous, current) =>
          current.status != previous.status &&
          current.status != InviteInboxStatus.idle,
      listener: (context, state) {
        switch (state.status) {
          case InviteInboxStatus.accepted:
            AppSnackbar.success(context, "You're in! Enjoy the sheet.");
            final pieceId = state.acceptedPieceId;
            if (pieceId != null) onAccepted(pieceId);
          case InviteInboxStatus.atCap:
            unawaited(_showPaywallGate(context));
          case InviteInboxStatus.failure:
            AppSnackbar.error(
              context,
              state.error ?? 'Something went wrong. Please try again.',
            );
          case InviteInboxStatus.idle:
            break; // Unreachable under listenWhen; the switch stays total.
        }
      },
      builder: (context, state) {
        if (state.invites.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.secondaryContainer,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                for (final invite in state.invites)
                  _InviteRow(
                    invite: invite,
                    busy: state.busyMessageIds.contains(invite.messageId),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The invite sheet's `_PaywallGateBody` pattern, adapted to this banner's
  /// transient context: the same `PaywallScreen` used everywhere else,
  /// rendered inside a bottom sheet rather than a route (G8: banners and
  /// sheets are not destinations).
  Future<void> _showPaywallGate(BuildContext context) {
    return AppBottomSheet.show<void>(
      context,
      title: 'This sheet is full',
      builder: (_) => BlocProvider<PaywallBloc>(
        create: (_) =>
            PaywallBloc(monetizationService: monetizationService)
              ..add(const PaywallStarted()),
        child: const SizedBox(height: 480, child: PaywallScreen()),
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.invite, required this.busy});

  final InviteMessage invite;
  final bool busy;

  /// The inviter's display label. The callable writes `''` for an owner
  /// with no display name (Firestore payloads have no nulls), so empty is
  /// normalized alongside absent.
  String get _ownerLabel {
    final name = invite.ownerName?.trim();
    return (name == null || name.isEmpty) ? 'Someone' : name;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InviteInboxCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: InitialsAvatar(
              initials: InviteFormat.initialsFor(invite.ownerId),
              color: Color(InviteFormat.colorValueFor(invite.ownerId)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // The invite payload deliberately carries no piece title: a
              // not-yet-collaborator can't read the piece document under the
              // M2.2 rules, so the title isn't knowable pre-accept.
              '$_ownerLabel invited you to collaborate on a sheet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          AppTextButton(
            onPressed: busy ? null : () => unawaited(cubit.accept(invite)),
            label: 'Accept',
            isLoading: busy,
          ),
          IconButton(
            onPressed: busy ? null : () => unawaited(cubit.dismiss(invite)),
            icon: const Icon(Icons.close),
            tooltip: 'Dismiss invite',
          ),
        ],
      ),
    );
  }
}
