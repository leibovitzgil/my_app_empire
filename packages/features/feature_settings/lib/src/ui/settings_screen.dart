import 'package:feature_settings/src/bloc/settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The settings screen: a single push-notifications toggle whose value is
/// persisted and reconciled against the OS permission on mount and resume.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
          final messenger = ScaffoldMessenger.of(context);
          switch (state.status) {
            case SettingsStatus.failure:
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(state.error ?? 'Something went wrong.'),
                    action: SnackBarAction(
                      label: 'Retry',
                      onPressed: () => context.read<SettingsBloc>().add(
                        const SettingsReconcileRequested(),
                      ),
                    ),
                  ),
                );
            case SettingsStatus.blocked:
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Notifications are blocked in system settings.',
                    ),
                  ),
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
