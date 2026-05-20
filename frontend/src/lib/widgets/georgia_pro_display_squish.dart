import 'package:flutter/material.dart';
import 'package:wellnest/theme/app_theme.dart';

/// Condensed editorial look: slightly narrower + taller than raw Georgia Pro (cf. news display headlines).
class GeorgiaProDisplaySquish extends StatelessWidget {
  const GeorgiaProDisplaySquish({
    super.key,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: kGeorgiaProDisplayScaleX,
      scaleY: kGeorgiaProDisplayScaleY,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      child: child,
    );
  }
}
