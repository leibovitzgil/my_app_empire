import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:duet/injection.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monetization/monetization.dart';

/// Hosts `feature_settings`'s Settings screen, plus the app-glue this
/// package can't own directly: a "Manage plan" row that opens
/// `feature_paywall`'s `PaywallScreen`, the same construction pattern already
/// used for the invite-flow paywall gate (see `showInviteSheet`).
///
/// Shown to every user: going Pro is per-account (it raises the per-sheet
/// collaborator cap), so there's no role to gate it on.
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadGateway());
  }

  Future<void> _loadGateway() async {
    final gateway = await getIt.getAsync<NotificationPermissionGateway>();
    if (mounted) setState(() => _gateway = gateway);
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
      child: SettingsScreen(
        extraTile: ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const Text('Manage plan'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPaywall(context),
        ),
      ),
    );
  }

  void _openPaywall(BuildContext context) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<PaywallBloc>(
            create: (_) =>
                PaywallBloc(monetizationService: getIt<MonetizationService>())
                  ..add(const PaywallStarted()),
            child: const PaywallScreen(),
          ),
        ),
      ),
    );
  }
}
