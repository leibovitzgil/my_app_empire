import 'package:core_ui/src/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// A search [AppTextField] with a decorative leading icon and a conditional
/// trailing clear button / loading indicator.
///
/// Composes [AppTextField] rather than duplicating a [TextField] so it stays
/// on the same themed border/fill/padding. Listens to [controller] so the
/// clear button appears only once there's text to clear.
class AppSearchField extends StatefulWidget {
  /// Creates an [AppSearchField].
  const AppSearchField({
    required this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onClear,
    this.enabled = true,
    this.isLoading = false,
    this.focusNode,
    super.key,
  });

  /// Controls the text being edited. Also drives the clear button.
  final TextEditingController controller;

  /// Placeholder text shown when the field is empty. Doubles as the field's
  /// accessible label via [InputDecoration.hintText].
  final String hint;

  /// Called whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the clear button is tapped. Defaults to clearing
  /// [controller] and firing [onChanged] with an empty string.
  final VoidCallback? onClear;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether to show a loading indicator in place of the clear button.
  final bool isLoading;

  /// An optional focus node to control focus externally.
  final FocusNode? focusNode;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _handleClear() {
    if (widget.onClear != null) {
      widget.onClear!();
      return;
    }
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      hint: widget.hint,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: _buildSuffix(),
    );
  }

  Widget? _buildSuffix() {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (widget.controller.text.isEmpty) {
      return null;
    }
    return Semantics(
      label: 'Clear search',
      button: true,
      child: IconButton(
        icon: const Icon(Icons.clear),
        onPressed: _handleClear,
      ),
    );
  }
}
