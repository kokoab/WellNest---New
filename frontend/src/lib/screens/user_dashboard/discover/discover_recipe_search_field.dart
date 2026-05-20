import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';

/// Discover tab recipe search input (hero, inline, or mobile overlay).
class DiscoverRecipeSearchField extends StatefulWidget {
  const DiscoverRecipeSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.searchOnlyMode,
    required this.onSubmitted,
    required this.onDebouncedQueryChanged,
    required this.onClearNonSearchMode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searchOnlyMode;
  final bool autofocus;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onDebouncedQueryChanged;
  final VoidCallback onClearNonSearchMode;

  @override
  State<DiscoverRecipeSearchField> createState() =>
      _DiscoverRecipeSearchFieldState();
}

class _DiscoverRecipeSearchFieldState extends State<DiscoverRecipeSearchField> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  OutlineInputBorder _outline(BuildContext context) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: wellnestOutlineColor(context), width: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      style: TextStyle(color: cs.onSurface),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by name or ingredients...',
        prefixIcon: Icon(Icons.search, color: cs.primary, size: 22),
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: wellnestCaptionColor(context),
                  size: 20,
                ),
                onPressed: () {
                  widget.controller.clear();
                  _debounce?.cancel();
                  if (widget.searchOnlyMode) {
                    setState(() {});
                    return;
                  }
                  widget.onClearNonSearchMode();
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: _outline(context),
        enabledBorder: _outline(context),
        focusedBorder: _outline(context),
        disabledBorder: _outline(context),
        errorBorder: _outline(context),
        focusedErrorBorder: _outline(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      onChanged: (value) {
        setState(() {});
        _debounce?.cancel();
        if (widget.searchOnlyMode) return;
        _debounce = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          widget.onDebouncedQueryChanged(value.trim());
        });
      },
      onSubmitted: widget.onSubmitted,
    );
  }
}
