import 'package:flutter/material.dart';
import 'delete_account_dialog.dart';

/// A button that triggers the delete account flow.
class DeleteAccountButton extends StatelessWidget {
  /// Callback function to execute when the user confirms deletion.
  final Future<void> Function() onDelete;

  /// The widget to display inside the button. Defaults to a Text widget.
  final Widget? child;

  /// Custom style for the button.
  final ButtonStyle? style;

  /// Title for the confirmation dialog.
  final String? confirmationTitle;

  /// Content for the confirmation dialog.
  final String? confirmationContent;

  /// Text for the cancel button in the confirmation dialog.
  final String? cancelText;

  /// Text for the delete button in the confirmation dialog.
  final String? deleteText;

  const DeleteAccountButton({
    super.key,
    required this.onDelete,
    this.child,
    this.style,
    this.confirmationTitle,
    this.confirmationContent,
    this.cancelText,
    this.deleteText,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: style ?? TextButton.styleFrom(foregroundColor: Colors.red),
      onPressed: () => _handlePress(context),
      child: child ?? const Text('Delete Account'),
    );
  }

  Future<void> _handlePress(BuildContext context) async {
    final confirmed = await showDeleteAccountDialog(
      context,
      title: confirmationTitle,
      content: confirmationContent,
      cancelText: cancelText,
      deleteText: deleteText,
    );

    if (confirmed == true) {
      await onDelete();
    }
  }
}
