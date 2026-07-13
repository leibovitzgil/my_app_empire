import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/local_piece_migrator.dart';
import 'package:duet/injection.dart';
import 'package:flutter/material.dart';
import 'package:local_storage/local_storage.dart';

/// A one-time, first-cloud-sign-in prompt offering to upload the device's
/// locally-created sheets to the signed-in user's account (M3.6).
///
/// Renders nothing: it schedules a post-frame check and, when there are local
/// sheets to migrate and the current user hasn't been prompted yet, shows a
/// [confirmDialog] and runs [LocalPieceMigrator.migrate] on accept. It is a
/// no-op unless a [LocalPieceMigrator] is registered — i.e. only under
/// `useFirebase: true`; the default/mock composition never migrates (G2).
class MigrationPrompt extends StatefulWidget {
  /// Creates a [MigrationPrompt].
  const MigrationPrompt({super.key});

  @override
  State<MigrationPrompt> createState() => _MigrationPromptState();
}

class _MigrationPromptState extends State<MigrationPrompt> {
  static const String _donePrefix = 'migration.pieces.done.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_maybePrompt()),
    );
  }

  Future<void> _maybePrompt() async {
    // Only the Firebase composition registers a migrator (G2: the mock/default
    // path has no cloud account to upload to).
    if (!getIt.isRegistered<LocalPieceMigrator>()) return;
    final uid = getIt<CurrentUser>().call();
    if (uid.isEmpty) return;

    final storage = getIt<LocalStorageService>();
    final doneKey = '$_donePrefix$uid';
    if (storage.getBool(doneKey) ?? false) return;

    final migrator = getIt<LocalPieceMigrator>();
    final pending = await migrator.pendingCount();
    if (pending == 0) {
      // Nothing to offer for this account; don't check again.
      await storage.setBool(doneKey, true);
      return;
    }

    if (!mounted) return;
    final accepted = await confirmDialog(
      context,
      title: 'Upload your sheets?',
      message:
          'You have $pending ${pending == 1 ? 'sheet' : 'sheets'} saved on '
          'this device. Upload them to your Duet account so they are backed '
          'up and sync across your devices.\n\nSheets shared with you offline '
          'upload as your own — their other collaborators are not carried '
          'over.',
      confirmLabel: 'Upload',
      cancelLabel: 'Not now',
    );

    // Prompted once, whatever the answer — a decline shouldn't nag on every
    // return to the library.
    await storage.setBool(doneKey, true);
    if (!accepted) return;

    final result = await migrator.migrate();
    if (!mounted) return;
    _showResult(result);
  }

  void _showResult(MigrationResult result) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final String message;
    if (result.migrated == 0 && result.failed > 0) {
      message = "Couldn't upload your sheets — they'll retry later.";
    } else if (result.failed > 0) {
      final total = result.migrated + result.failed;
      message =
          'Uploaded ${result.migrated} of $total sheets; the rest will '
          'retry later.';
    } else {
      message =
          'Uploaded ${result.migrated} '
          '${result.migrated == 1 ? 'sheet' : 'sheets'} to your account.';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
