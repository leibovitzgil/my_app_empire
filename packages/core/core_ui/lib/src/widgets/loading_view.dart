import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// A centered loading placeholder: a [CircularProgressIndicator] with an
/// optional [label] beneath it.
///
/// A design-system primitive for the loading state of any screen that fetches
/// remote data — the counterpart to `EmptyStateView`/`ErrorRetryView` for the
/// "still working" state. Shares the same text style scale as those two so
/// all three "screen state" widgets read as one visual family.
///
/// The outer `Semantics` excludes its descendants' own semantics (the
/// spinner's default role, the label `Text`'s implicit label) so a screen
/// reader announces the loading state exactly once instead of a merged,
/// duplicated node.
class LoadingView extends StatelessWidget {
  /// Creates a [LoadingView].
  const LoadingView({this.label, super.key});

  /// An optional line of copy shown below the spinner, e.g. "Loading list…".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      label: label ?? 'Loading',
      excludeSemantics: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                label!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
