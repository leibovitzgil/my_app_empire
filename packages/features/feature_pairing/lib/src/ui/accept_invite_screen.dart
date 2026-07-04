import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_pairing/src/bloc/accept_invite_cubit.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';
import 'package:feature_pairing/src/ui/invite_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Entry widget for the Accept Invite screen (opened via deep link): builds
/// an [AcceptInviteCubit] for [token]/[studentId] and loads it immediately.
class AcceptInvitePage extends StatelessWidget {
  /// Creates an [AcceptInvitePage].
  const AcceptInvitePage({
    required this.inviteService,
    required this.token,
    required this.studentId,
    required this.onAccepted,
    super.key,
  });

  /// Resolves and accepts the invite.
  final InviteService inviteService;

  /// The token extracted from the deep link — see `InviteDeepLinks.tokenFrom`
  /// for the format the app-glue layer's deep link parser should extract
  /// this from.
  final String token;

  /// The accepting (signed-in) student's id.
  final String studentId;

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
          token: token,
          studentId: studentId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: AcceptInviteScreen(onAccepted: onAccepted),
    );
  }
}

/// The Accept Invite body: piece title + teacher, Accept/Decline. Reads
/// [AcceptInviteCubit] from context (provided by [AcceptInvitePage]).
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
            name: 'Teacher ${InviteFormat.initialsFor(details.teacherId)}',
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
