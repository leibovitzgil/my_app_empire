import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// The contextual toolbar shown only while drawing.
///
/// In collaboration mode every participant draws in their own auto-assigned
/// layer colour (there's no manual colour picking), so this shows that colour
/// as a read-only "your ink" indicator alongside the eraser toggle and undo.
class DrawToolbar extends StatelessWidget {
  /// Creates a [DrawToolbar].
  const DrawToolbar({
    required this.penColor,
    required this.eraserActive,
    required this.canUndo,
    required this.onEraserToggled,
    required this.onUndo,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Your ink colour',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Container(
                  width: 24,
                  height: 24,
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
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.md),
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
          ],
        ),
      ),
    );
  }
}
