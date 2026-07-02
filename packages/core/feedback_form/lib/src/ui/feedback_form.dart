import 'package:core_ui/core_ui.dart';
import 'package:feedback_form/src/domain/feedback_entry.dart';
import 'package:feedback_form/src/domain/feedback_repository.dart';
import 'package:flutter/material.dart';

/// A form for collecting a star rating and a free-text message, and
/// submitting it via [repository].
class FeedbackForm extends StatefulWidget {
  /// Creates a [FeedbackForm] that submits through [repository]. [onSubmitted]
  /// is called once submission succeeds.
  const FeedbackForm({required this.repository, super.key, this.onSubmitted});

  /// Where the completed feedback is submitted.
  final FeedbackRepository repository;

  /// Called after a successful submission.
  final VoidCallback? onSubmitted;

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _messageController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _rating == 0) {
      setState(() {
        _errorText = 'Add a message and a star rating before submitting.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final result = await widget.repository.submitFeedback(
      FeedbackEntry(message: message, rating: _rating),
    );
    if (!mounted) return;

    result.fold(
      (_) {
        setState(() => _isSubmitting = false);
        widget.onSubmitted?.call();
      },
      (_) {
        setState(() {
          _isSubmitting = false;
          _errorText = 'Could not send feedback. Please try again.';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                key: ValueKey('feedback_star_$star'),
                icon: Icon(
                  star <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                tooltip: '$star star${star == 1 ? '' : 's'}',
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _rating = star),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          enabled: !_isSubmitting,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Your feedback',
            border: OutlineInputBorder(),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Submit feedback',
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
