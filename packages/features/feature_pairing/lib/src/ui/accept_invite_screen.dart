import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_pairing/src/bloc/accept_invite_cubit.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';
import 'package:feature_pairing/src/ui/invite_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

/// Entry widget for the Accept Invite screen (opened via deep link): builds
/// an [AcceptInviteCubit] for [token]/[studentId] and loads it immediately.
class AcceptInvitePage extends StatelessWidget {
  /// Creates an [AcceptInvitePage].
  const AcceptInvitePage({
    required this.inviteService,
    required this.pieceRepository,
    required this.monetizationService,
    required this.token,
    required this.studentId,
    required this.onAccepted,
    this.studentName,
    this.studentEmail,
    super.key,
  });

  /// Resolves and accepts the invite.
  final InviteService inviteService;

  /// Used to re-check the collaborator cap/already-collaborator status
  /// before allowing acceptance.
  final PieceRepository pieceRepository;

  /// Used to resolve the owner's current monetization tier for the cap
  /// re-check.
  final MonetizationService monetizationService;

  /// The token extracted from the deep link — see `InviteDeepLinks.tokenFrom`
  /// for the format the app-glue layer's deep link parser should extract
  /// this from.
  final String token;

  /// The accepting (signed-in) student's id.
  final String studentId;

  /// The accepting student's display name, if known — passed through to
  /// [AcceptInviteCubit].
  final String? studentName;

  /// The accepting student's email, if known — passed through to
  /// [AcceptInviteCubit] (AC-2: acceptance records uid+email).
  final String? studentEmail;

  /// Called once the invite is accepted, with the now-paired piece's id, so
  /// the app-glue layer can navigate into it (e.g. via `feature_library`'s
  /// Piece Detail or straight to `feature_score`'s viewer).
  final void Function(String pieceId) onAccepted;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AcceptInviteCubit>(
      create: (_) {
        final cubit = AcceptInviteCubit(
          inviteService: inviteService,
          pieceRepository: pieceRepository,
          monetizationService: monetizationService,
          token: token,
          studentId: studentId,
          studentName: studentName,
          studentEmail: studentEmail,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: AcceptInviteScreen(onAccepted: onAccepted),
    );
  }
}

/// The Accept Invite body: piece title + teacher, Accept/Decline (or an
/// already-collaborator/at-cap body instead). Reads [AcceptInviteCubit] from
/// context (provided by [AcceptInvitePage]).
class AcceptInviteScreen extends StatelessWidget {
  /// Creates an [AcceptInviteScreen].
  const AcceptInviteScreen({required this.onAccepted, super.key});

  /// See [AcceptInvitePage.onAccepted].
  final void Function(String pieceId) onAccepted;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AcceptInviteCubit, AcceptInviteState>(
      listenWhen: (previous, current) =>
          (current.status == AcceptInviteStatus.accepted &&
              previous.status != AcceptInviteStatus.accepted) ||
          (current.error != null && current.error != previous.error),
      listener: (context, state) {
        if (state.status == AcceptInviteStatus.accepted) {
          AppSnackbar.success(context, "You're paired! Enjoy the piece.");
          final pieceId = state.details?.pieceId;
          if (pieceId != null) onAccepted(pieceId);
        } else if (state.error != null) {
          AppSnackbar.error(context, state.error!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Invite')),
          body: switch (state.status) {
            AcceptInviteStatus.loading => const LoadingView(
              label: 'Loading invite…',
            ),
            AcceptInviteStatus.failure => ErrorRetryView(
              title: "Couldn't open this invite",
              message: state.error,
              onRetry: () => context.read<AcceptInviteCubit>().load(),
            ),
            AcceptInviteStatus.alreadyCollaborator => _AlreadyCollaboratorBody(
              state: state,
              onContinue: onAccepted,
            ),
            AcceptInviteStatus.atCap => _AtCapBody(state: state),
            AcceptInviteStatus.ready ||
            AcceptInviteStatus.accepting ||
            AcceptInviteStatus.accepted => _ReadyBody(state: state),
          },
        );
      },
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.state});

  final AcceptInviteState state;

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    if (details == null) return const SizedBox.shrink();
    final busy = state.status == AcceptInviteStatus.accepting;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            details.pieceTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          PersonTile(
            initials: InviteFormat.initialsFor(details.teacherId),
            color: Color(InviteFormat.colorValueFor(details.teacherId)),
            name:
                details.teacherName ??
                'Teacher ${InviteFormat.initialsFor(details.teacherId)}',
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Accept',
            isLoading: busy,
            onPressed: busy
                ? null
                : () => context.read<AcceptInviteCubit>().accept(),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Decline',
            onPressed: busy ? null : () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Shown when the accepting user is already a collaborator on this piece —
/// e.g. re-opening an already-consumed invite. Offers a single "Continue" to
/// just navigate in, rather than an "Accept" that would re-run the mutation.
class _AlreadyCollaboratorBody extends StatelessWidget {
  const _AlreadyCollaboratorBody({
    required this.state,
    required this.onContinue,
  });

  final AcceptInviteState state;

  /// See [AcceptInvitePage.onAccepted] — invoked directly (no mutation to
  /// wait on) since the accepter already has access.
  final void Function(String pieceId) onContinue;

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            "You're already a collaborator on "
            '${details?.pieceTitle ?? 'this piece'}.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Continue',
            onPressed: () {
              final pieceId = details?.pieceId;
              if (pieceId != null) {
                onContinue(pieceId);
              } else {
                unawaited(Navigator.of(context).maybePop());
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Shown when the piece is already at its collaborator cap for the owner's
/// current monetization tier — the same message copy as the email-invite and
/// deep-link creation paths, so the story is consistent regardless of which
/// path the accepter arrived through.
class _AtCapBody extends StatelessWidget {
  const _AtCapBody({required this.state});

  final AcceptInviteState state;

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            details?.pieceTitle ?? 'This piece',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Free plan allows 1 collaborator. Ask the owner to upgrade to '
            'invite more.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(
            label: 'Got it',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
