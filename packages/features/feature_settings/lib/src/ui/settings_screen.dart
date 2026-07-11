import 'package:core_ui/core_ui.dart';
import 'package:feature_settings/src/bloc/settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The settings screen: a single push-notifications toggle whose value is
/// persisted and reconciled against the OS permission on mount and resume.
class SettingsScreen extends StatefulWidget {
  /// Creates a [SettingsScreen]. [extraTiles] render below the notifications
  /// row — slots for app-specific settings rows (e.g. a profile group or a
  /// "Manage plan" entry) without this package taking a direct dependency on
  /// whatever features those rows navigate to.
  const SettingsScreen({super.key, this.extraTiles = const <Widget>[]});

  /// Extra rows rendered, in order, below the notifications toggle.
  final List<Widget> extraTiles;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => context.read<SettingsBloc>().add(
        const SettingsReconcileRequested(),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocListener<SettingsBloc, SettingsState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          switch (state.status) {
            case SettingsStatus.failure:
              AppSnackbar.error(
                context,
                state.error ?? 'Something went wrong.',
                actionLabel: 'Retry',
                onAction: () => context.read<SettingsBloc>().add(
                  const SettingsReconcileRequested(),
                ),
              );
            case SettingsStatus.blocked:
              AppSnackbar.info(
                context,
                'Notifications are blocked in system settings.',
              );
            case SettingsStatus.loading:
            case SettingsStatus.loaded:
            case SettingsStatus.pending:
              break;
          }
        },
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            final interactive =
                state.status == SettingsStatus.loaded ||
                state.status == SettingsStatus.failure;
            final blocked = state.status == SettingsStatus.blocked;
            return ListView(
              children: [
                SwitchListTile(
                  value: state.pushEnabled,
                  onChanged: interactive
                      ? (enabled) => context.read<SettingsBloc>().add(
                          SettingsPushToggled(enabled: enabled),
                        )
                      : null,
                  title: const Text('Push notifications'),
                  subtitle: Text(_subtitleFor(state.status, state.pushEnabled)),
                  secondary: const Icon(Icons.notifications),
                ),
                if (blocked)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => context.read<SettingsBloc>().add(
                          const SettingsOpenSystemSettingsRequested(),
                        ),
                        child: const Text('Open settings'),
                      ),
                    ),
                  ),
                ...widget.extraTiles,
              ],
            );
          },
        ),
      ),
    );
  }

  String _subtitleFor(SettingsStatus status, bool pushEnabled) {
    if (status == SettingsStatus.blocked) {
      return 'Blocked in system settings';
    }
    return pushEnabled ? 'On' : 'Off';
  }
}
