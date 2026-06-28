import 'package:flutter/material.dart';

/// A tappable "N items need attention" banner that toggles the flags-only
/// filter. Hidden when there's nothing to attend to and the filter is off.
class AttentionSummary extends StatelessWidget {
  /// Creates an [AttentionSummary].
  const AttentionSummary({
    required this.count,
    required this.flagsOnly,
    required this.onTap,
    super.key,
  });

  /// Number of flagged items.
  final int count;

  /// Whether the flags-only filter is currently active.
  final bool flagsOnly;

  /// Toggles the filter.
  final VoidCallback onTap;

  static const Color _amber = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    if (count == 0 && !flagsOnly) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final label = flagsOnly
        ? 'Showing items that need attention'
        : '$count ${count == 1 ? 'item needs' : 'items need'} attention';

    final semanticsLabel = flagsOnly
        ? '$label, tap to clear filter'
        : '$label, tap to filter';
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          color: _amber.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.flag, size: 18, color: _amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                flagsOnly ? Icons.close : Icons.chevron_right,
                size: 18,
                color: _amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
