import 'package:flutter/material.dart';

/// Brand seed color - used for both light and dark themes.
const Color kWellGreen = Color(0xFF097333);
const Color kNestOrange = Color(0xFFEF5026);
const Color kAccentYellow = Color(0xFFFDB813);

/// Light theme
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kWellGreen,
    brightness: Brightness.light,
    primary: kWellGreen,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: kWellGreen,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
);

/// Dark theme
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kWellGreen,
    brightness: Brightness.dark,
    primary: kWellGreen,
    surface: const Color(0xFF1E1E1E),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  cardColor: const Color(0xFF2C2C2C),
);

/// Font families: Recoleta (main), Helvetica Now (sub).
const String kFontRecoleta = 'Recoleta';
const String kFontHelveticaNow = 'HelveticaNow';

/// Brand colors and shared design tokens for consistency.
class AppColors {
  static const Color wellGreen = kWellGreen;
  static const Color nestOrange = kNestOrange;
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
