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

/// The reader top bar's shared status-badge shell: an outlined pill
/// (transparent fill, `outlineVariant` border) fronted by either an [icon]
/// or a colour [dotColor] (never both), followed by [label].
///
/// [SyncStatusBadge] and `ReaderTopBar`'s "Drawing in your layer"/"Clean
/// workspace" badges all share this one shell so the three read as one
/// visual family instead of drifting apart.
class StatusPill extends StatelessWidget {
  /// Creates a [StatusPill].
  const StatusPill({required this.label, this.icon, this.dotColor, super.key})
    : assert(
        icon == null || dotColor == null,
        'StatusPill takes an icon or a dot, never both.',
      );

  /// The pill's text.
  final String label;

  /// A leading glyph, mutually exclusive with [dotColor].
  final IconData? icon;

  /// A leading colour dot (e.g. a participant's own ink colour), mutually
  /// exclusive with [icon].
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              if (dotColor != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, subtle badge showing [status], built from the shared
/// [StatusPill] shell.
class SyncStatusBadge extends StatelessWidget {
  /// Creates a [SyncStatusBadge].
  const SyncStatusBadge({required this.status, super.key});

  /// The status to display.
  final ScoreSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      ScoreSyncStatus.synced => ('Synced', Icons.cloud_done_outlined),
      ScoreSyncStatus.syncing => ('Syncing…', Icons.cloud_sync_outlined),
      ScoreSyncStatus.notSynced => ('Not synced', Icons.cloud_off_outlined),
    };
    return StatusPill(label: label, icon: icon);
  }
}
