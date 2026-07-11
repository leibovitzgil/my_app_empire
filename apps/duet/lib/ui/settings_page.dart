import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/injection.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_loadGateway());
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
              const _SectionHeader('Profile'),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(account?.displayName ?? 'Set your name'),
                subtitle: const Text('Display name'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => unawaited(_editDisplayName(account?.displayName)),
              ),
              if (account?.email != null)
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: Text(account!.email!),
                  subtitle: const Text('Email'),
                ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                enabled: !_signingOut,
                onTap: _signingOut ? null : () => unawaited(_signOut()),
              ),
              const _SectionHeader('Plan'),
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Manage plan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/paywall'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A low-key group label between settings rows.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
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
