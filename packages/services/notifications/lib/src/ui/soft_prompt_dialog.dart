import 'package:flutter/material.dart';

class SoftPromptDialog extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onLater;
  final String title;
  final String description;
  final String allowButtonText;
  final String laterButtonText;

  const SoftPromptDialog({
    super.key,
    required this.onAllow,
    required this.onLater,
    this.title = 'Enable Notifications',
    this.description = 'Stay updated with the latest news and updates. '
        'We promise not to spam you!',
    this.allowButtonText = 'Allow',
    this.laterButtonText = 'Maybe Later',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(description),
      actions: [
        TextButton(
          onPressed: onLater,
          child: Text(laterButtonText),
        ),
        ElevatedButton(
          onPressed: onAllow,
          child: Text(allowButtonText),
        ),
      ],
    );
  }
}
