import 'package:feedback_form/src/domain/feedback_repository.dart';
import 'package:feedback_form/src/ui/feedback_form.dart';
import 'package:flutter/material.dart';

/// A dialog wrapping [FeedbackForm], dismissing itself on successful
/// submission.
class FeedbackDialog extends StatelessWidget {
  /// Creates a [FeedbackDialog] that submits through [repository].
  const FeedbackDialog({required this.repository, super.key, this.title});

  /// Where the completed feedback is submitted.
  final FeedbackRepository repository;

  /// The dialog title. Defaults to `'Send Feedback'`.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title ?? 'Send Feedback'),
      content: FeedbackForm(
        repository: repository,
        onSubmitted: () => Navigator.of(context).pop(true),
      ),
    );
  }
}

/// Shows the [FeedbackDialog]. Resolves to `true` if feedback was submitted,
/// `null` if dismissed without submitting.
Future<bool?> showFeedbackDialog(
  BuildContext context, {
  required FeedbackRepository repository,
  String? title,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => FeedbackDialog(repository: repository, title: title),
  );
}
