import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// The contextual toolbar shown only while drawing: a floating pill above
/// the mode segmented control.
///
/// In collaboration mode every participant draws in their own auto-assigned
/// layer colour (there's no manual colour picking), so this shows that colour
/// as a read-only "your ink" indicator alongside the eraser toggle, undo,
/// and a "Done" action that exits back to view mode.
class DrawToolbar extends StatelessWidget {
  /// Creates a [DrawToolbar].
  const DrawToolbar({
    required this.penColor,
    required this.eraserActive,
    required this.canUndo,
    required this.onEraserToggled,
    required this.onUndo,
    required this.onDone,
    super.key,
  });

  /// The signed-in participant's own layer colour — the colour their strokes
  /// are drawn in.
  final Color penColor;

  /// Whether the eraser (rather than the pen) is active.
  final bool eraserActive;

  /// Whether there is a stroke to undo.
  final bool canUndo;

  /// Called when the eraser toggle is tapped.
  final VoidCallback onEraserToggled;

  /// Called when the undo button is tapped.
  final VoidCallback onUndo;

  /// Called when "Done" is tapped — the caller exits draw mode.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Your ink colour',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: penColor,
                    border: Border.all(color: scheme.onSurface, width: 2),
                  ),
                ),
              ),
            ),
            Text(
              'Your ink',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
            _Divider(color: scheme.outlineVariant),
            Semantics(
              button: true,
              label: eraserActive
                  ? 'Eraser, active. Double tap to switch back to the pen.'
                  : 'Eraser. Double tap to activate.',
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  isSelected: eraserActive,
                  icon: const Icon(Icons.auto_fix_normal_outlined),
                  selectedIcon: Icon(
                    Icons.auto_fix_normal,
                    color: scheme.primary,
                  ),
                  onPressed: onEraserToggled,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: canUndo
                  ? 'Undo last stroke'
                  : 'Undo, no strokes to undo yet',
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: canUndo ? onUndo : null,
                ),
              ),
            ),
            _Divider(color: scheme.outlineVariant),
            AppTextButton(label: 'Done', onPressed: onDone),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      color: color,
    );
  }
}
