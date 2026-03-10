import 'package:flutter/material.dart';

/// Brand color palette
const Color kPrimaryGreen = Color(0xFF097333);
const Color kAccentOrange = Color(0xFFEF5026);
const Color kAccentYellow = Color(0xFFF9BD21);
const Color kBackgroundCream = Color(0xFFFDFBF7);
const Color kSurfaceWarmGray = Color(0xFFEAE6DF);
const Color kImagePlaceholderGreen = Color(0xFFE8F1EC);
const Color kBodyTextDark = Color(0xFF333333);
const Color kCaptionGray = Color(0xFF666666);

/// Legacy aliases (for gradual migration)
const Color kWellGreen = kPrimaryGreen;
const Color kNestOrange = kAccentOrange;

/// Light theme — warm, organic, vibrant, premium
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'HelveticaNow',
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryGreen,
    brightness: Brightness.light,
    primary: kPrimaryGreen,
    secondary: kAccentOrange,
    surface: kSurfaceWarmGray,
    onSurface: kBodyTextDark,
  ),
  scaffoldBackgroundColor: kBackgroundCream,
  cardColor: kSurfaceWarmGray,
  appBarTheme: const AppBarTheme(
    backgroundColor: kBackgroundCream,
    foregroundColor: kPrimaryGreen,
    elevation: 0,
    iconTheme: IconThemeData(color: kPrimaryGreen),
    titleTextStyle: TextStyle(
      fontFamily: 'Recoleta',
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: kPrimaryGreen,
    ),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Recoleta',
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: kPrimaryGreen,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Recoleta',
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: kPrimaryGreen,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Recoleta',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: kPrimaryGreen,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Recoleta',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: kPrimaryGreen,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'HelveticaNow',
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: kBodyTextDark,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'HelveticaNow',
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: kBodyTextDark,
    ),
    labelSmall: TextStyle(
      fontFamily: 'HelveticaNow',
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: kBodyTextDark,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryGreen,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 48),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontFamily: 'HelveticaNow', fontWeight: FontWeight.bold),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    hintStyle: TextStyle(color: kPrimaryGreen.withOpacity(0.5), fontSize: 16),
  ),
);

/// Dark theme
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'HelveticaNow',
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryGreen,
    brightness: Brightness.dark,
    primary: kPrimaryGreen,
    secondary: kAccentOrange,
    surface: const Color(0xFF1E1E1E),
    onSurface: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF2C2C2C),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    foregroundColor: Colors.white,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontFamily: 'Recoleta',
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
);

/// Font families
const String kFontRecoleta = 'Recoleta';
const String kFontHelveticaNow = 'HelveticaNow';

/// Brand colors and shared design tokens
class AppColors {
  static const Color primaryGreen = kPrimaryGreen;
  static const Color accentOrange = kAccentOrange;
  static const Color accentYellow = kAccentYellow;
  static const Color backgroundCream = kBackgroundCream;
  static const Color surfaceWarmGray = kSurfaceWarmGray;
  static const Color imagePlaceholderGreen = kImagePlaceholderGreen;
  static const Color bodyText = kBodyTextDark;
  static const Color captionText = kCaptionGray;
  static const Color wellGreen = kPrimaryGreen;
  static const Color nestOrange = kAccentOrange;
}

/// Standardized animation durations
class AppDurations {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 400);
}

/// Standardized curves
class AppCurves {
  static const Curve standard = Curves.easeInOut;
}

const double kMinTapTargetSize = 48.0;

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
