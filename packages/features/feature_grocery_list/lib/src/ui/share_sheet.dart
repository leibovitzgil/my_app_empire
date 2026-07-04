import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_grocery_list/src/bloc/members_bloc.dart';
import 'package:feature_grocery_list/src/data/invite_identity.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/ui/grocery_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the "Share list" sheet for the given [bloc]. The bloc is provided by
/// the page (so the roster keeps streaming) and handed in via `.value`.
Future<void> showShareSheet({
  required BuildContext context,
  required MembersBloc bloc,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider<MembersBloc>.value(
      value: bloc,
      child: const ShareSheet(),
    ),
  );
}

/// The share UI: the live member roster, an add-by-email field, and a copyable
/// invite link — the place a person is added to (or removed from) the list.
class ShareSheet extends StatefulWidget {
  /// Creates a [ShareSheet].
  const ShareSheet({super.key});

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final next = isValidEmail(_controller.text);
      if (next != _valid) setState(() => _valid = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _invite() {
    final email = _controller.text.trim();
    if (!isValidEmail(email)) return;
    context.read<MembersBloc>().add(MemberInvited(email));
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  void _copyLink() {
    final link = context.read<MembersBloc>().inviteLink;
    unawaited(Clipboard.setData(ClipboardData(text: link)));
    AppSnackbar.success(context, 'Invite link copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.read<MembersBloc>().currentUser;
    return BlocListener<MembersBloc, MembersState>(
      listenWhen: (previous, current) =>
          (current.actionMessage != null &&
              current.actionMessage != previous.actionMessage) ||
          (current.actionError != null &&
              current.actionError != previous.actionError),
      listener: (context, state) {
        final error = state.actionError;
        final message = state.actionMessage;
        if (error != null) {
          AppSnackbar.error(context, error);
        } else if (message != null) {
          AppSnackbar.success(context, message);
        }
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share list', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'People you add can view and edit this list together.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            BlocBuilder<MembersBloc, MembersState>(
              buildWhen: (previous, current) =>
                  previous.members != current.members,
              builder: (context, state) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final member in state.members)
                    _MemberTile(member: member, currentUser: me),
                ],
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _controller,
                    hint: 'Add by email…',
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _invite(),
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _valid ? _invite : null,
                  child: const Text('Invite'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.link),
                label: const Text('Copy invite link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the roster: avatar, name (or "You"), role/pending, and a remove
/// affordance for everyone except the owner and yourself.
class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.currentUser});

  final ListMember member;
  final Collaborator currentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final who = member.collaborator;
    final isYou = who.id == currentUser.id;
    final name = isYou ? 'You' : who.name;
    final subtitle = member.isPending
        ? 'Invited · pending'
        : (member.isOwner ? 'Owner' : 'Editor');
    final canRemove = !member.isOwner && !isYou;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: InitialsAvatar(
        initials: who.initials,
        color: GroceryFormat.collaboratorColor(who),
        radius: 18,
      ),
      title: Text(name),
      subtitle: Text(
        subtitle,
        style: member.isPending
            ? theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              )
            : null,
      ),
      trailing: canRemove
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove ${who.name}',
              onPressed: () => unawaited(_confirmRemove(context)),
            )
          : null,
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final bloc = context.read<MembersBloc>();
    final confirmed = await confirmDialog(
      context,
      title: 'Remove ${member.collaborator.name}?',
      message: 'They will lose access to this list.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed) {
      bloc.add(MemberRemoved(member.collaborator.id));
    }
  }
}
