import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_pairing/src/bloc/invite_bloc.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the "Invite a student" flow for [pieceId] (owned by [teacherId]).
///
/// Builds and owns an [InviteBloc] for the lifetime of the sheet — the
/// paywall-gate check (see [InviteBloc._onOpened]) runs first via
/// [InviteSheetOpened]; a gated teacher sees `feature_paywall`'s
/// `PaywallScreen` rendered in place of the normal sheet body instead of the
/// invite affordances, rather than a separate navigation. This is a judgment
/// call: the brief asks for the paywall check to gate the sheet "first", but
/// checking pro status is inherently async, so there's no synchronous point
/// to decide "open the sheet at all" — rendering `PaywallScreen` as the
/// sheet's very first content accomplishes the same "you never see the
/// invite UI while gated" outcome.
Future<void> showInviteSheet(
  BuildContext context, {
  required InviteService inviteService,
  required MonetizationService monetizationService,
  required PieceRepository pieceRepository,
  required String teacherId,
  required String pieceId,
  String? teacherName,
}) async {
  final bloc = InviteBloc(
    inviteService: inviteService,
    monetizationService: monetizationService,
    pieceRepository: pieceRepository,
    teacherId: teacherId,
    pieceId: pieceId,
    teacherName: teacherName,
  )..add(const InviteSheetOpened());
  await AppBottomSheet.show<void>(
    context,
    title: 'Invite a student',
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

class _InviteSheetBody extends StatelessWidget {
  const _InviteSheetBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InviteBloc, InviteState>(
      listenWhen: (previous, current) =>
          (current.status == InviteStatus.created &&
              previous.status != InviteStatus.created) ||
          (current.error != null && current.error != previous.error),
      listener: (context, state) {
        if (state.status == InviteStatus.created) {
          AppSnackbar.success(context, 'Invite link created');
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
          InviteStatus.creating ||
          InviteStatus.created ||
          InviteStatus.failure => _ReadyBody(state: state),
        };
      },
    );
  }
}

/// Rendered in place of the invite sheet's normal body when the teacher is
/// at/over the free-tier student limit — the same `PaywallScreen` used
/// elsewhere in the app, re-skinned only by its own copy (not forked).
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
  const _ReadyBody({required this.state});

  final InviteState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = state.link;
    final busy = state.status == InviteStatus.creating;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share this link with your student to pair them on this piece.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
        ] else
          PrimaryButton(
            label: 'Get invite link',
            isLoading: busy,
            onPressed: busy
                ? null
                : () => context.read<InviteBloc>().add(
                    const InviteLinkCreateRequested(),
                  ),
          ),
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
