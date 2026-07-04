import 'package:core_ui/core_ui.dart';
import 'package:feature_score/src/ui/widgets/ink_palette.dart';
import 'package:flutter/material.dart';

/// A contextual toolbar shown only while drawing: the fixed 5-colour swatch
/// row, an eraser toggle, and an undo button.
class PenColorPicker extends StatelessWidget {
  /// Creates a [PenColorPicker].
  const PenColorPicker({
    required this.selectedColorId,
    required this.eraserActive,
    required this.canUndo,
    required this.onColorSelected,
    required this.onEraserToggled,
    required this.onUndo,
    super.key,
  });

  /// The index of the currently selected swatch.
  final int selectedColorId;

  /// Whether the eraser (rather than the pen) is active.
  final bool eraserActive;

  /// Whether there is a stroke to undo.
  final bool canUndo;

  /// Called with the tapped swatch's index.
  final ValueChanged<int> onColorSelected;

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
            for (var i = 0; i < kInkPalette.length; i++) _swatch(context, i),
            const SizedBox(width: AppSpacing.sm),
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

  Widget _swatch(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = !eraserActive && selectedColorId == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        label: 'Pen colour ${index + 1}${isSelected ? ', selected' : ''}',
        child: SizedBox(
          width: 48,
          height: 48,
          child: InkWell(
            onTap: () => onColorSelected(index),
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kInkPalette[index],
                  border: isSelected
                      ? Border.all(color: scheme.onSurface, width: 3)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
