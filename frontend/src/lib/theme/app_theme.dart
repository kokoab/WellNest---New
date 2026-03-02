import 'package:flutter/material.dart';

/// Font families: Recoleta (main), Helvetica Now (sub).
const String kFontRecoleta = 'Recoleta';
const String kFontHelveticaNow = 'HelveticaNow';

/// Brand colors and shared design tokens for consistency.
class AppColors {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color bodyText = Color(0xFF333333);
  static const Color captionText = Color(0xFF666666);
  /// Background color (cream/beige)
  static const Color background = Color(0xFFFFEECC);
}

/// Standardized animation durations to avoid stutter and ensure smooth UX.
class AppDurations {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 400);
}

/// Standardized curves for consistent feel.
class AppCurves {
  static const Curve standard = Curves.easeInOut;
}

/// Minimum tap target size for accessibility (48x48 logical pixels).
const double kMinTapTargetSize = 48.0;

/// Main typography (Recoleta) – headings, titles, app name.
TextStyle recoleta({
  double? fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) =>
    TextStyle(
      fontFamily: kFontRecoleta,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );

/// Sub typography (Helvetica Now) – body, captions, labels.
TextStyle helveticaNow({
  double? fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) =>
    TextStyle(
      fontFamily: kFontHelveticaNow,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
