import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// The Score Viewer's non-blocking review-sync affordance.
///
/// This is a presentational, standalone enum deliberately decoupled from
/// `review_sync`'s actual service — wiring a live value in is app-glue work
/// for a later phase; for now callers pass a static value (e.g.
/// [ScoreSyncStatus.synced]) and this badge renders it.
enum ScoreSyncStatus {
  /// Fully up to date with the other participant.
  synced,

  /// A sync is in progress.
  syncing,

  /// No sync has happened yet (or the last one failed).
  notSynced,
}

/// A small, subtle badge showing [status].
class SyncStatusBadge extends StatelessWidget {
  /// Creates a [SyncStatusBadge].
  const SyncStatusBadge({required this.status, super.key});

  /// The status to display.
  final ScoreSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon) = switch (status) {
      ScoreSyncStatus.synced => ('Synced', Icons.cloud_done_outlined),
      ScoreSyncStatus.syncing => ('Syncing…', Icons.cloud_sync_outlined),
      ScoreSyncStatus.notSynced => ('Not synced', Icons.cloud_off_outlined),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        visualDensity: VisualDensity.compact,
        backgroundColor: scheme.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
    );
  }
}
