import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:duet/domain/duet_roles.dart';
import 'package:duet/ui/role_selection/role_selection_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A one-time, post-signup screen: pick Teacher or Student, then confirm.
/// Shown by `AppView`'s redirect whenever the signed-in user has no role
/// assigned yet; skipped otherwise.
class RoleSelectionScreen extends StatelessWidget {
  /// Creates a [RoleSelectionScreen].
  const RoleSelectionScreen({required this.onConfirmed, super.key});

  /// Called once the role has been persisted, so the app-glue layer can
  /// navigate on (typically to `/home`).
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoleSelectionCubit, RoleSelectionState>(
      listenWhen: (previous, current) =>
          (current.status == RoleSelectionStatus.saved &&
              previous.status != RoleSelectionStatus.saved) ||
          (current.error != null && current.error != previous.error),
      listener: (context, state) {
        if (state.status == RoleSelectionStatus.saved) {
          onConfirmed();
        } else if (state.error != null) {
          AppSnackbar.error(context, state.error!);
        }
      },
      builder: (context, state) {
        final cubit = context.read<RoleSelectionCubit>();
        final busy = state.status == RoleSelectionStatus.saving;
        return Scaffold(
          appBar: AppBar(title: const Text("What's your role?")),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Are you teaching or learning on Duet?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                _RoleCard(
                  icon: Icons.school_outlined,
                  title: 'Teacher',
                  subtitle: 'Import pieces and invite students',
                  selected: state.selected == DuetRoles.teacher,
                  onTap: () => cubit.select(DuetRoles.teacher),
                ),
                const SizedBox(height: AppSpacing.md),
                _RoleCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Student',
                  subtitle: 'Practice pieces your teacher shares with you',
                  selected: state.selected == DuetRoles.student,
                  onTap: () => cubit.select(DuetRoles.student),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Continue',
                  isLoading: busy,
                  onPressed: state.selected == null || busy
                      ? null
                      : () => unawaited(cubit.confirm()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}
