import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A button that opens the Privacy Policy in an external browser.
class PrivacyPolicyButton extends StatelessWidget {
  /// The URL of the privacy policy.
  final String privacyPolicyUrl;

  /// The widget to display inside the button. Defaults to a Text widget.
  final Widget? child;

  /// Custom style for the button.
  final ButtonStyle? style;

  const PrivacyPolicyButton({
    super.key,
    required this.privacyPolicyUrl,
    this.child,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: style,
      onPressed: () => _launchUrl(context),
      child: child ?? const Text('Privacy Policy'),
    );
  }

  Future<void> _launchUrl(BuildContext context) async {
    try {
      final Uri url = Uri.parse(privacyPolicyUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch privacy policy.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching privacy policy: $e')),
        );
      }
    }
  }
}
