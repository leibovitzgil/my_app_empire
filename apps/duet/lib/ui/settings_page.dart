import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/account_purge.dart';
import 'package:duet/data/data_export.dart';
import 'package:duet/data/directory_publisher.dart';
import 'package:duet/injection.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_compliance/legal_compliance.dart';
import 'package:local_storage/local_storage.dart';

/// Hosts `feature_settings`'s Settings screen, plus the app-glue this
/// package can't own directly: a "Profile" group (display-name editing,
/// read-only email, sign-out — M1.5) sourced from the auth account stream,
/// and a "Manage plan" row that opens `feature_paywall`'s screen via the
/// `/paywall` route (G8: full-screen destinations are routes).
///
/// Shown to every user: going Pro is per-account (it raises the per-sheet
/// collaborator cap), so there's no role to gate it on. Sign-out needs no
/// navigation here — the auth redirect in `app.dart` lands every signed-out
/// location on `/login` automatically.
class DuetSettingsPage extends StatefulWidget {
  /// Creates a [DuetSettingsPage].
  const DuetSettingsPage({super.key});

  @override
  State<DuetSettingsPage> createState() => _DuetSettingsPageState();
}

class _DuetSettingsPageState extends State<DuetSettingsPage> {
  // Resolved lazily/async (see `injection.dart`), mirroring `DuetScorePage`'s
  // `RecordingPathBuilder` loading pattern — fetched here, once, the first
  // time Settings is actually opened.
  NotificationPermissionGateway? _gateway;
  var _signingOut = false;
  var _deleting = false;
  var _exporting = false;
  late bool _discoverable = getIt<DirectoryPublisher>().discoverable;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGateway());
  }

  Future<void> _setDiscoverable(bool value) async {
    // Optimistic flip; reverted below if persisting/publishing fails.
    setState(() => _discoverable = value);
    final result = await getIt<DirectoryPublisher>().setDiscoverable(value);
    if (!mounted) return;
    if (result case ResultFailure<void>()) {
      setState(() => _discoverable = !value);
      AppSnackbar.error(
        context,
        'Could not update your visibility. Please try again.',
      );
    }
  }

  Future<void> _loadGateway() async {
    final gateway = await getIt.getAsync<NotificationPermissionGateway>();
    if (mounted) setState(() => _gateway = gateway);
  }

  Future<void> _editDisplayName(String? currentName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialName: currentName),
    );
    if (newName == null || !mounted) return;
    final result = await getIt<AuthRepository>().updateDisplayName(newName);
    if (!mounted) return;
    switch (result) {
      case Success<void>():
        AppSnackbar.success(context, 'Name updated.');
      case ResultFailure<void>(:final error):
        AppSnackbar.error(
          context,
          (error is AuthFailure ? error.message : null) ??
              'Something went wrong. Please try again.',
        );
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    final result = await getIt<AuthRepository>().logout();
    if (!mounted) return;
    setState(() => _signingOut = false);
    if (result case ResultFailure<void>(:final error)) {
      AppSnackbar.error(
        context,
        (error is AuthFailure ? error.message : null) ??
            'Could not sign out. Please try again.',
      );
    }
    // On success the auth redirect lands on /login by itself.
  }

  /// The GDPR self-service export flow (M7.5): ask the backend to gather
  /// everything Duet holds about the account into a JSON bundle and hand the
  /// resulting download link to the share-sheet (the sharing lives behind the
  /// `DataExport` seam, so this never touches a platform channel headlessly).
  /// A once-a-day server rate limit surfaces as its own retry-less message.
  Future<void> _downloadData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final result = await getIt<DataExport>().exportMyData();
      if (!mounted) return;
      switch (result) {
        case Success<void>():
          AppSnackbar.success(
            context,
            'Your data export is ready to share.',
          );
        case ResultFailure<void>(:final error):
          final failure = error is DataExportFailure ? error : null;
          AppSnackbar.error(
            context,
            failure?.message ?? 'Could not export your data. Please try again.',
            // The daily-limit rejection can't be fixed by retrying now, so it
            // gets no Retry action; everything else does.
            actionLabel: failure?.kind == DataExportFailureKind.rateLimited
                ? null
                : 'Retry',
            onAction: failure?.kind == DataExportFailureKind.rateLimited
                ? null
                : () => unawaited(_downloadData()),
          );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// The post-confirmation deletion flow (M1.9): re-authenticate (the M1.8
  /// callable rejects any sign-in older than 5 minutes, so a fresh
  /// credential is collected up front, not just reactively), purge
  /// server-side, and only then wipe local caches and sign out — a failed
  /// purge leaves the session fully intact, never half-signed-out.
  Future<void> _deleteAccount(AuthProviderKind provider) async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      Future<bool> reauth() => showReauthDialog(
        context,
        provider: provider,
        reauthenticate: getIt<AuthRepository>().reauthenticate,
      );
      if (!await reauth() || !mounted) return;

      bool needsFreshLogin(Result<void> result) => switch (result) {
        ResultFailure<void>(
          error: AuthFailure(code: AuthFailureCode.requiresRecentLogin),
        ) =>
          true,
        _ => false,
      };

      var result = await getIt<AccountPurge>().deleteAccount();
      // The freshness window can still lapse (e.g. the OAuth sheet sat open
      // too long): collect another credential and retry until the user
      // backs out.
      while (needsFreshLogin(result)) {
        if (!mounted || !await reauth() || !mounted) return;
        result = await getIt<AccountPurge>().deleteAccount();
      }
      if (!mounted) return;

      switch (result) {
        case Success<void>():
          // The server-side account no longer exists. Wipe every local
          // cache (pieces, annotations, invites, review-sync cursors,
          // settings — the whole store is account-scoped), then sign out;
          // the auth redirect lands on /login.
          await getIt<LocalStorageService>().clear();
          await getIt<AuthRepository>().logout();
        case ResultFailure<void>(:final error):
          AppSnackbar.error(
            context,
            (error is AuthFailure ? error.message : null) ??
                'Could not delete your account. Please try again.',
            actionLabel: 'Retry',
            onAction: () => unawaited(_deleteAccount(provider)),
          );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateway = _gateway;
    if (gateway == null) {
      return const Scaffold(body: LoadingView());
    }
    return BlocProvider<SettingsBloc>(
      create: (_) => SettingsBloc(
        repository: getIt<SettingsRepository>(),
        gateway: gateway,
      )..add(const SettingsReconcileRequested()),
      child: StreamBuilder<AuthAccount?>(
        stream: getIt<AuthAccountProvider>().account,
        builder: (context, snapshot) {
          final account = snapshot.data;
          return SettingsScreen(
            extraTiles: [
              const SectionHeader('Profile'),
              AppListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(account?.displayName ?? 'Set your name'),
                subtitle: const Text('Display name'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => unawaited(_editDisplayName(account?.displayName)),
              ),
              if (account?.email != null)
                AppListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: Text(account!.email!),
                  subtitle: const Text('Email'),
                ),
              AppListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                enabled: !_signingOut,
                onTap: _signingOut ? null : () => unawaited(_signOut()),
              ),
              const SectionHeader('Privacy'),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_outlined),
                title: const Text('Discoverable by email'),
                subtitle: const Text(
                  'Invites to your email only work when this is on.',
                ),
                value: _discoverable,
                onChanged: (value) => unawaited(_setDiscoverable(value)),
              ),
              // GDPR self-service export (M7.5): a copy of everything Duet
              // stores about you, delivered as a downloadable JSON bundle via
              // the share-sheet. Non-destructive, so it sits here — not in the
              // danger zone — beside the other privacy controls.
              AppListTile(
                leading: _exporting
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.download_outlined),
                title: const Text('Download my data'),
                subtitle: const Text(
                  'Get a copy of everything Duet stores about you.',
                ),
                enabled: !_exporting,
                onTap: _exporting ? null : () => unawaited(_downloadData()),
              ),
              const SectionHeader('Plan'),
              AppListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Manage plan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/paywall'),
              ),
              // The App-Store-mandated in-app account deletion (M1.9).
              // `DeleteAccountButton` owns the confirm dialog; everything
              // after confirmation lives in `_deleteAccount`.
              const SectionHeader('Danger zone'),
              if (_deleting)
                const AppListTile(
                  leading: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  title: Text('Deleting your account…'),
                )
              else
                DeleteAccountButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  confirmationContent:
                      'This permanently deletes your account, your sheet '
                      'music, annotations, and recordings, and removes you '
                      'from the collaborator directory. This cannot be '
                      'undone.',
                  onDelete: () => _deleteAccount(
                    account?.provider ?? AuthProviderKind.unknown,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Collects a new display name; pops with the trimmed value on Save, null on
/// cancel. Validation (non-empty, ≤ 50 chars) is enforced inline.
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({this.initialName});

  final String? initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  static const _maxLength = 50;

  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName ?? '',
  );

  String? get _validationError {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return 'Name cannot be empty.';
    if (trimmed.length > _maxLength) {
      return 'Keep it under $_maxLength characters.';
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _validationError;
    return AlertDialog(
      title: const Text('Display name'),
      content: AppTextField(
        controller: _controller,
        label: 'Name',
        errorText: error,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: error != null
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
