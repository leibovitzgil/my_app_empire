import 'package:core_ui/core_ui.dart';
import 'package:feature_score/src/bloc/score_bloc.dart';
import 'package:flutter/material.dart';

/// The reader's floating View / Draw / Passage mode switch.
///
/// Replaces the old pair of mode FABs with a single always-visible control,
/// built from [Material]/[InkWell] (not `SegmentedButton`, whose default
/// styling doesn't fit the dark reader shell).
class ModeSegmentedControl extends StatelessWidget {
  /// Creates a [ModeSegmentedControl].
  const ModeSegmentedControl({
    required this.mode,
    required this.onModeSelected,
    super.key,
  });

  /// The currently active mode.
  final ScoreMode mode;

  /// Called with the newly-selected mode when a segment is tapped.
  final ValueChanged<ScoreMode> onModeSelected;

  static const List<ScoreMode> _modes = [
    ScoreMode.view,
    ScoreMode.draw,
    ScoreMode.regionSelect,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in _modes)
              _ModeSegment(
                mode: m,
                selected: m == mode,
                onTap: () => onModeSelected(m),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ScoreMode mode;
  final bool selected;
  final VoidCallback onTap;

  (String, IconData) get _labelAndIcon => switch (mode) {
    ScoreMode.view => ('View', Icons.menu_book_outlined),
    ScoreMode.draw => ('Draw', Icons.draw_outlined),
    ScoreMode.regionSelect => ('Passage', Icons.crop_free_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon) = _labelAndIcon;
    final foreground = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label mode${selected ? ', selected' : ''}',
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              // Excluded so the visible label never doubles up with the
              // outer Semantics node's richer "mode, selected" one.
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: foreground),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
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
