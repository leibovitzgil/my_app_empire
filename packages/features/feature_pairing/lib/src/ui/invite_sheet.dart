import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_pairing/src/bloc/invite_bloc.dart';
import 'package:feature_pairing/src/domain/collaborator_invite_service.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';
import 'package:feature_pairing/src/ui/invite_format.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the "Invite a collaborator" flow for [pieceId] (owned by
/// [teacherId]): email is the PRIMARY path (live lookup-as-you-type via
/// [collaboratorInviteService]), with the tokenized deep-link
/// [inviteService] always available as a "Share invite link instead"
/// fallback.
///
/// Builds and owns an [InviteBloc] for the lifetime of the sheet — the
/// per-piece paywall-gate check (see [InviteBloc._onOpened]) runs first via
/// [InviteSheetOpened]; a gated owner sees `feature_paywall`'s
/// `PaywallScreen` rendered in place of the normal sheet body instead of the
/// invite affordances, rather than a separate navigation. This is a judgment
/// call: the brief asks for the paywall check to gate the sheet "first", but
/// checking pro status is inherently async, so there's no synchronous point
/// to decide "open the sheet at all" — rendering `PaywallScreen` as the
/// sheet's very first content accomplishes the same "you never see the
/// invite UI while gated" outcome.
Future<void> showInviteSheet(
  BuildContext context, {
  required CollaboratorInviteService collaboratorInviteService,
  required InviteService inviteService,
  required MonetizationService monetizationService,
  required PieceRepository pieceRepository,
  required String teacherId,
  required String pieceId,
  String? teacherName,
}) async {
  final bloc = InviteBloc(
    collaboratorInviteService: collaboratorInviteService,
    inviteService: inviteService,
    monetizationService: monetizationService,
    pieceRepository: pieceRepository,
    teacherId: teacherId,
    pieceId: pieceId,
    teacherName: teacherName,
  )..add(const InviteSheetOpened());
  await AppBottomSheet.show<void>(
    context,
    title: 'Invite a collaborator',
    builder: (_) => BlocProvider<InviteBloc>.value(
      value: bloc,
      child: BlocProvider<PaywallBloc>(
        create: (_) =>
            PaywallBloc(monetizationService: monetizationService)
              ..add(const PaywallStarted()),
        child: const _InviteSheetBody(),
      ),
    ),
  );
  await bloc.close();
}

class _InviteSheetBody extends StatefulWidget {
  const _InviteSheetBody();

  @override
  State<_InviteSheetBody> createState() => _InviteSheetBodyState();
}

class _InviteSheetBodyState extends State<_InviteSheetBody> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InviteBloc, InviteState>(
      listenWhen: (previous, current) =>
          (current.status == InviteStatus.sent &&
              previous.status != InviteStatus.sent) ||
          (current.error != null && current.error != previous.error),
      listener: (context, state) {
        if (state.status == InviteStatus.sent) {
          AppSnackbar.success(
            context,
            state.link != null ? 'Invite link created' : 'Invite sent',
          );
        } else if (state.error != null) {
          AppSnackbar.error(context, state.error!);
        }
      },
      builder: (context, state) {
        return switch (state.status) {
          InviteStatus.checkingAccess => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: LoadingView(),
          ),
          InviteStatus.paywallRequired => const _PaywallGateBody(),
          InviteStatus.ready ||
          InviteStatus.lookingUp ||
          InviteStatus.resolved ||
          InviteStatus.notFound ||
          InviteStatus.alreadyCollaborator ||
          InviteStatus.sending ||
          InviteStatus.sent => _ReadyBody(
            state: state,
            emailController: _controller,
          ),
        };
      },
    );
  }
}

/// Rendered in place of the invite sheet's normal body when the owner is
/// at/over the collaborator cap — the same `PaywallScreen` used elsewhere in
/// the app, re-skinned only by its own copy (not forked).
class _PaywallGateBody extends StatelessWidget {
  const _PaywallGateBody();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 480,
      child: PaywallScreen(),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.state, required this.emailController});

  final InviteState state;
  final TextEditingController emailController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = state.status == InviteStatus.sending;
    final link = state.link;
    final recipient = state.recipient;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite a collaborator by email to work on this piece together.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: emailController,
          label: 'Email',
          hint: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enabled: !busy && link == null,
          errorText: switch (state.status) {
            InviteStatus.notFound =>
              'No Duet account found for ${state.email}.',
            InviteStatus.alreadyCollaborator =>
              '${state.email} is already a collaborator.',
            _ => null,
          },
          onChanged: (value) =>
              context.read<InviteBloc>().add(InviteEmailChanged(value)),
        ),
        if (state.status == InviteStatus.resolved && recipient != null) ...[
          const SizedBox(height: AppSpacing.sm),
          PersonTile(
            initials: InviteFormat.initialsFor(recipient.uid),
            color: Color(InviteFormat.colorValueFor(recipient.uid)),
            name: recipient.displayName ?? recipient.email,
          ),
        ],
        if (state.status == InviteStatus.sent && link == null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Invite sent to ${recipient?.email ?? state.email}.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (link != null) ...[
          SelectableText(link.uri.toString()),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Copy link',
                  onPressed: () => _copyLink(context, link.uri),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SecondaryButton(
                  label: 'Share',
                  onPressed: () => unawaited(_shareLink(link.uri)),
                ),
              ),
            ],
          ),
        ] else ...[
          PrimaryButton(
            label: 'Send invite',
            isLoading: busy,
            onPressed: state.status == InviteStatus.resolved && !busy
                ? () => context.read<InviteBloc>().add(
                    const InviteSendRequested(),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          const LabeledDivider(label: 'or'),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Share invite link instead',
            isLoading: busy,
            onPressed: busy
                ? null
                : () => context.read<InviteBloc>().add(
                    const InviteLinkCreateRequested(),
                  ),
          ),
        ],
      ],
    );
  }

  void _copyLink(BuildContext context, Uri uri) {
    unawaited(Clipboard.setData(ClipboardData(text: uri.toString())));
    AppSnackbar.success(context, 'Invite link copied to clipboard');
  }

  Future<void> _shareLink(Uri uri) {
    return SharePlus.instance.share(
      ShareParams(uri: uri, subject: 'Join me on Duet'),
    );
  }
}
