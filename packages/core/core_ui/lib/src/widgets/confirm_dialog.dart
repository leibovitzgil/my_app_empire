import 'package:core_ui/src/widgets/primary_button.dart';
import 'package:flutter/material.dart';

/// Shows a confirmation dialog and resolves to whether the user confirmed.
///
/// Always resolves — dismissing via the barrier, back button or Esc resolves
/// to `false`, same as tapping the cancel action, so callers never need to
/// handle a `null` result.
///
/// Pass `isDestructive: true` for irreversible/destructive actions (e.g.
/// delete). Per the UX brief's "avoid accidental confirmation" guidance, the
/// dialog then starts with focus on the cancel action rather than confirm.
///
/// Shape comes from `AppTheme`'s `dialogTheme` — this function never
/// hardcodes it.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            autofocus: isDestructive,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          PrimaryButton(
            label: confirmLabel,
            isDestructive: isDestructive,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      );
    },
  );
  // No use of the outer `context` after the await above: the barrier/back
  // dismissal case already resolves `showDialog` to `null`, handled by `??`.
  return result ?? false;
}
