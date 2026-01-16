import 'package:flutter/material.dart';

/// A dialog that asks for confirmation to delete an account.
class DeleteAccountDialog extends StatelessWidget {
  final String? title;
  final String? content;
  final String? cancelText;
  final String? deleteText;

  const DeleteAccountDialog({
    super.key,
    this.title,
    this.content,
    this.cancelText,
    this.deleteText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title ?? 'Delete Account?'),
      content: Text(content ?? 'This action is irreversible. All your data will be permanently removed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText ?? 'Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(deleteText ?? 'Delete'),
        ),
      ],
    );
  }
}

/// Shows the [DeleteAccountDialog].
Future<bool?> showDeleteAccountDialog(BuildContext context, {
  String? title,
  String? content,
  String? cancelText,
  String? deleteText,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => DeleteAccountDialog(
      title: title,
      content: content,
      cancelText: cancelText,
      deleteText: deleteText,
    ),
  );
}
