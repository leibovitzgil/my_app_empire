import 'package:flutter/material.dart';

/// A horizontal divider with a centered [label] — e.g. an "or" separator
/// between a primary action and alternative actions on a form.
class LabeledDivider extends StatelessWidget {
  /// Creates a [LabeledDivider] showing [label] between two rules.
  const LabeledDivider({required this.label, super.key});

  /// The text shown between the two divider rules.
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: color)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
