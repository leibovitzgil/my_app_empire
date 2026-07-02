import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feedback_form/feedback_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monetization/monetization.dart';
import 'package:showcase/injection.dart';
import 'package:user_roles/user_roles.dart';

/// The signed-in home screen, with an entry point into the paywall.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openPaywall(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider(
            create: (_) => PaywallBloc(
              monetizationService: getIt<MonetizationService>(),
            )..add(const PaywallStarted()),
            child: const PaywallScreen(),
          ),
        ),
      ),
    );
  }

  void _openFeedback(BuildContext context) {
    unawaited(
      showFeedbackDialog(
        context,
        repository: getIt<FeedbackRepository>(),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider(
            create: (_) => SettingsBloc(
              repository: getIt<SettingsRepository>(),
              gateway: getIt<NotificationPermissionGateway>(),
            )..add(const SettingsReconcileRequested()),
            child: const SettingsScreen(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome! You are signed in.'),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Go Pro',
              onPressed: () => _openPaywall(context),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _openFeedback(context),
              child: const Text('Send Feedback'),
            ),
            TextButton(
              onPressed: () =>
                  context.read<AuthBloc>().add(AuthLogoutRequested()),
              child: const Text('Sign out'),
            ),
            PermissionGate(
              repository: getIt<UserRoleRepository>(),
              permission: Permissions.viewAdminPanel,
              child: const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Chip(label: Text('Admin panel unlocked')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
