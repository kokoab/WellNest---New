import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';

/// Wraps a child with a press-scale micro-interaction.
/// Scales down to 0.95 on tap down and back to 1.0 on release/cancel.
/// Provide [semanticLabel] for screen readers when the child has no text.
class AnimatedPressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  /// Optional label for accessibility (e.g. "View recipe").
  final String? semanticLabel;

  const AnimatedPressScale({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  @override
  State<AnimatedPressScale> createState() => _AnimatedPressScaleState();
}

class _AnimatedPressScaleState extends State<AnimatedPressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.short,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.standard),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _onTap() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final gesture = GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null ? _onTap : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
    if (widget.semanticLabel != null) {
      return Semantics(
        button: true,
        label: widget.semanticLabel,
        enabled: widget.onTap != null,
        child: gesture,
      );
    }
    return gesture;
  }
}
