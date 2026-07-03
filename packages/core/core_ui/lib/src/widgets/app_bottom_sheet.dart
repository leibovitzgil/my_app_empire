import 'dart:math' as math;

import 'package:core_ui/src/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// A modal bottom sheet helper with a real, screen-reader-operable close
/// affordance and keyboard-inset-aware padding.
///
/// Shape and background come from `AppTheme`'s `bottomSheetTheme` (see PR1),
/// which also sets `showDragHandle: false` — this helper draws its own
/// decorative drag handle plus a title/close row so the accessible close
/// control (below) always has somewhere to live.
abstract final class AppBottomSheet {
  /// Shows a modal bottom sheet containing [builder]'s content, resolving to
  /// whatever value the content passes to `Navigator.pop`.
  ///
  /// If [title] is provided, it is rendered as an accessible heading. A real
  /// close [IconButton] is always shown next to the title *unless*
  /// [isDismissible] is `false`: drag-to-dismiss and barrier-tap dismissal
  /// aren't discoverable or operable via screen reader, so the close button
  /// is what makes the sheet actually dismissible for those users. When a
  /// caller explicitly opts out of dismissibility (`isDismissible: false`)
  /// they presumably want the sheet closeable only via their own in-content
  /// action, so the close button is omitted in that case too, to respect
  /// that intent.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    String? title,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      builder: (sheetContext) => _AppBottomSheetContent(
        title: title,
        isDismissible: isDismissible,
        builder: builder,
      ),
    );
  }
}

class _AppBottomSheetContent extends StatelessWidget {
  const _AppBottomSheetContent({
    required this.title,
    required this.isDismissible,
    required this.builder,
  });

  final String? title;
  final bool isDismissible;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: math.max(AppSpacing.lg, bottomInset + AppSpacing.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          if (title != null || isDismissible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (isDismissible)
                    Semantics(
                      label: 'Close',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(child: builder(context)),
          ),
        ],
      ),
    );
  }
}
