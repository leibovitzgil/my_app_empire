import 'package:flutter/material.dart';

/// A themed single-line text field.
///
/// A thin wrapper around [TextField] that inherits its fill color, border and
/// content padding entirely from `AppTheme`'s `inputDecorationTheme` — this
/// widget never overrides radius/fill/border colors per instance.
class AppTextField extends StatelessWidget {
  /// Creates an [AppTextField].
  const AppTextField({
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    super.key,
  });

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// The floating label shown above the field's content.
  final String? label;

  /// Placeholder text shown when the field is empty.
  final String? hint;

  /// An error message shown below the field, styled via the error border.
  final String? errorText;

  /// The type of keyboard to show, e.g. [TextInputType.emailAddress].
  final TextInputType? keyboardType;

  /// The action button to show on the keyboard, e.g. [TextInputAction.next].
  final TextInputAction? textInputAction;

  /// Called whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field, e.g. via the keyboard action.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether the field should be focused as soon as it's built.
  final bool autofocus;

  /// Whether to enable platform autocorrect.
  final bool autocorrect;

  /// How to capitalize text entered by the user.
  final TextCapitalization textCapitalization;

  /// An optional focus node to control focus externally.
  final FocusNode? focusNode;

  /// An optional widget shown at the start of the field.
  final Widget? prefixIcon;

  /// An optional widget shown at the end of the field.
  final Widget? suffixIcon;

  /// Whether to hide the entered text, e.g. for passwords.
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      focusNode: focusNode,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
