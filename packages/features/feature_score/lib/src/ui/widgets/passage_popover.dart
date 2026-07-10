import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// The passage-select action menu, shown once a region drag completes.
///
/// Anchored next to the selection (via `FractionalRegionAlign` in
/// `score_viewer_screen.dart`) at ≥600dp; falls back to an `AppBottomSheet`
/// on narrower screens. Either way it offers the same three actions, honest
/// about what's actually known about the selection (no fabricated "System 3
/// · Bars 12–15" — just [title]).
class PassagePopover extends StatelessWidget {
  /// Creates a [PassagePopover].
  const PassagePopover({
    required this.onPractice,
    required this.onRecord,
    required this.onCancel,
    this.title = 'This passage',
    super.key,
  });

  /// Called when "Practice this passage" is tapped.
  final VoidCallback onPractice;

  /// Called when "Record an audio note" is tapped.
  final VoidCallback onRecord;

  /// Called when "Cancel" is tapped (or, per the caller, when the user taps
  /// outside the popover).
  final VoidCallback onCancel;

  /// The header text.
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.cardRadius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: SizedBox(
        width: 248,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              _PopoverAction(
                icon: Icons.piano,
                label: 'Practice this passage',
                onTap: onPractice,
              ),
              _PopoverAction(
                icon: Icons.mic_none_outlined,
                label: 'Record an audio note',
                semanticLabel: 'Record an audio note for this passage',
                onTap: onRecord,
              ),
              Divider(
                height: 1,
                color: scheme.outlineVariant,
                indent: AppSpacing.sm,
                endIndent: AppSpacing.sm,
              ),
              _PopoverAction(
                icon: Icons.close,
                label: 'Cancel',
                semanticLabel: 'Cancel region selection',
                onTap: onCancel,
                muted: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopoverAction extends StatelessWidget {
  const _PopoverAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = muted ? scheme.onSurfaceVariant : scheme.onSurface;
    final iconColor = muted ? scheme.onSurfaceVariant : scheme.primary;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.smRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              // Excluded so the visible (short) label never doubles up with
              // the outer Semantics node's (sometimes richer) one.
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(icon, size: 21, color: iconColor),
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: muted
                              ? FontWeight.normal
                              : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
