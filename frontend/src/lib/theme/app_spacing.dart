import 'package:flutter/material.dart';

/// Centralized spacing system for consistent padding, margins, and gaps.
/// Replace hardcoded values with these constants throughout the app.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0; // Default standard padding
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Horizontal gaps (SizedBox width)
  static const Widget gapH4 = SizedBox(width: xs);
  static const Widget gapH8 = SizedBox(width: sm);
  static const Widget gapH16 = SizedBox(width: md);
  static const Widget gapH24 = SizedBox(width: lg);
  static const Widget gapH32 = SizedBox(width: xl);
  static const Widget gapH48 = SizedBox(width: xxl);

  // Vertical gaps (SizedBox height)
  static const Widget gapV4 = SizedBox(height: xs);
  static const Widget gapV8 = SizedBox(height: sm);
  static const Widget gapV16 = SizedBox(height: md);
  static const Widget gapV24 = SizedBox(height: lg);
  static const Widget gapV32 = SizedBox(height: xl);
  static const Widget gapV48 = SizedBox(height: xxl);
}
