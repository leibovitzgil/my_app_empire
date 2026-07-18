import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A button that opens the Terms of Service in an external browser.
///
/// The sibling of `PrivacyPolicyButton` — same launch behaviour and failure
/// handling, for the other document every store listing requires.
class TermsOfServiceButton extends StatelessWidget {
  /// Creates a [TermsOfServiceButton].
  const TermsOfServiceButton({
    required this.termsOfServiceUrl,
    super.key,
    this.child,
    this.style,
  });

  /// The URL of the terms of service.
  final String termsOfServiceUrl;

  /// The widget to display inside the button. Defaults to a Text widget.
  final Widget? child;

  /// Custom style for the button.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: style,
      onPressed: () => _launchUrl(context),
      child: child ?? const Text('Terms of Service'),
    );
  }

  Future<void> _launchUrl(BuildContext context) async {
    try {
      final url = Uri.parse(termsOfServiceUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch terms of service.')),
          );
        }
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching terms of service: $e')),
        );
      }
    }
  }
}
