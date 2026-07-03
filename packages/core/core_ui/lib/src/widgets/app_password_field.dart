import 'package:core_ui/src/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// A password [AppTextField] with a visibility toggle.
///
/// Composes [AppTextField] rather than duplicating a [TextField] so it stays
/// on the same themed border/fill/padding. Toggling visibility only flips
/// local state — it never steals focus from the field.
class AppPasswordField extends StatefulWidget {
  /// Creates an [AppPasswordField].
  const AppPasswordField({
    this.controller,
    this.label = 'Password',
    this.hint,
    this.errorText,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// The floating label shown above the field's content.
  final String label;

  /// Placeholder text shown when the field is empty.
  final String? hint;

  /// An error message shown below the field, styled via the error border.
  final String? errorText;

  /// The action button to show on the keyboard.
  final TextInputAction? textInputAction;

  /// Called whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field, e.g. via the keyboard action.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether the field should be focused as soon as it's built.
  final bool autofocus;

  /// An optional focus node to control focus externally.
  final FocusNode? focusNode;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  void _toggleObscured() {
    setState(() {
      _obscured = !_obscured;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      errorText: widget.errorText,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      suffixIcon: Semantics(
        label: _obscured ? 'Show password' : 'Hide password',
        toggled: !_obscured,
        child: IconButton(
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: _toggleObscured,
        ),
      ),
    );
  }
}
